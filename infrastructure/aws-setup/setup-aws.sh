#!/bin/bash
set -e

AWS_ACCOUNT_ID=""
ALERT_EMAIL=""
GITHUB_REPO=""
AWS_REGION=""
DB_PASSWORD=""
JWT_SECRET=""
BUCKET_NAME=""
GITHUB_ROLE_ARN=""
TOPIC_ARN=""

CONFIG_FILE="setup-config.json"

declare -A SETUP_STATUS
SETUP_STATUS[S3]=false
SETUP_STATUS[DYNAMODB]=false
SETUP_STATUS[OIDC]=false
SETUP_STATUS[IAMROLE]=false
SETUP_STATUS[SNS]=false
SETUP_STATUS[BUDGET]=false
SETUP_STATUS[SSM]=false

test_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "ERROR: AWS CLI not installed"
        echo "Install from: https://awscli.amazonaws.com/"
        exit 1
    fi
    echo "AWS CLI installed"
}

test_aws_credentials() {
    if ! AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>&1); then
        echo "ERROR: AWS credentials not configured"
        echo "Run: aws configure"
        exit 1
    fi
    echo "AWS Account ID: $AWS_ACCOUNT_ID"
    export AWS_ACCOUNT_ID
}

get_user_inputs() {
    local saved_config=""

    if [ -f "$CONFIG_FILE" ]; then
        saved_config=$(cat "$CONFIG_FILE" 2>/dev/null || echo "")
        if [ -n "$saved_config" ]; then
            echo "Found saved configuration from previous run"
        fi
    fi

    while true; do
        local default_email=$(echo "$saved_config" | grep -o '"ALERT_EMAIL":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$default_email" ]; then
            read -p "Email for cost alerts [$default_email]: " email_input
            ALERT_EMAIL="${email_input:-$default_email}"
        else
            read -p "Email for cost alerts: " ALERT_EMAIL
        fi

        if [[ "$ALERT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        fi
        echo "Invalid email format"
    done

    while true; do
        local default_repo=$(echo "$saved_config" | grep -o '"GITHUB_REPO":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$default_repo" ]; then
            read -p "GitHub repository (format: username/repo) [$default_repo]: " repo_input
            GITHUB_REPO="${repo_input:-$default_repo}"
        else
            read -p "GitHub repository (format: username/repo): " GITHUB_REPO
        fi

        if [[ "$GITHUB_REPO" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
            break
        fi
        echo "Invalid format. Expected: username/repo-name"
    done

    local default_region=$(echo "$saved_config" | grep -o '"AWS_REGION":"[^"]*"' | cut -d'"' -f4)
    default_region="${default_region:-eu-west-3}"
    read -p "AWS region [$default_region]: " region_input
    AWS_REGION="${region_input:-$default_region}"
    export AWS_DEFAULT_REGION=$AWS_REGION

    cat > "$CONFIG_FILE" <<EOF
{
  "ALERT_EMAIL": "$ALERT_EMAIL",
  "GITHUB_REPO": "$GITHUB_REPO",
  "AWS_REGION": "$AWS_REGION"
}
EOF

    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
}

create_terraform_state_bucket() {
    BUCKET_NAME="eshop-terraform-state-${AWS_ACCOUNT_ID}"

    if aws s3 ls "s3://${BUCKET_NAME}" &> /dev/null; then
        echo "S3 bucket exists: $BUCKET_NAME"
        SETUP_STATUS[S3]=true
        return
    fi

    echo "Creating S3 bucket: $BUCKET_NAME"

    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" &> /dev/null
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION" &> /dev/null
    fi

    if [ $? -eq 0 ]; then
        aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled &> /dev/null

        aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }' &> /dev/null

        aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true &> /dev/null

        echo "S3 bucket created successfully"
        SETUP_STATUS[S3]=true
    else
        echo "SKIPPED: S3 bucket (insufficient permissions)"
    fi
}

create_dynamodb_lock_table() {
    local table_name="eshop-terraform-locks"

    if aws dynamodb describe-table --table-name "$table_name" &> /dev/null; then
        echo "DynamoDB table exists: $table_name"
        SETUP_STATUS[DYNAMODB]=true
        return
    fi

    echo "Creating DynamoDB table: $table_name"

    aws dynamodb create-table \
        --table-name "$table_name" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" &> /dev/null

    if [ $? -eq 0 ]; then
        echo "DynamoDB table created successfully"
        SETUP_STATUS[DYNAMODB]=true
    else
        echo "SKIPPED: DynamoDB table (insufficient permissions)"
    fi
}

create_github_oidc() {
    local provider_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

    if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" &> /dev/null; then
        echo "OIDC provider exists"
        SETUP_STATUS[OIDC]=true
    else
        echo "Creating OIDC provider"
        aws iam create-open-id-connect-provider \
            --url https://token.actions.githubusercontent.com \
            --client-id-list sts.amazonaws.com \
            --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 &> /dev/null

        [ $? -eq 0 ] && SETUP_STATUS[OIDC]=true
    fi

    cat > /tmp/github-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$provider_arn"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

    local role_name="GitHubActionsRole"

    if aws iam get-role --role-name "$role_name" &> /dev/null; then
        echo "IAM role exists: $role_name"
        SETUP_STATUS[IAMROLE]=true
    else
        echo "Creating IAM role: $role_name"
        aws iam create-role --role-name "$role_name" --assume-role-policy-document file:///tmp/github-trust-policy.json &> /dev/null

        if [ $? -eq 0 ]; then
            aws iam attach-role-policy --role-name "$role_name" --policy-arn arn:aws:iam::aws:policy/AdministratorAccess &> /dev/null
            SETUP_STATUS[IAMROLE]=true
        fi
    fi

    GITHUB_ROLE_ARN=$(aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text 2>&1)
    rm -f /tmp/github-trust-policy.json
}

create_cost_alerts() {
    local topic_name="eshop-cost-alerts"

    local result=$(aws sns create-topic --name "$topic_name" --output json 2>&1)
    if [ $? -eq 0 ]; then
        TOPIC_ARN=$(echo "$result" | grep -o '"TopicArn":"[^"]*"' | cut -d'"' -f4)
        echo "SNS topic created: $TOPIC_ARN"
        SETUP_STATUS[SNS]=true
    else
        TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, '${topic_name}')].TopicArn" --output text 2>/dev/null)
        if [ -n "$TOPIC_ARN" ]; then
            echo "SNS topic exists: $TOPIC_ARN"
            SETUP_STATUS[SNS]=true
        else
            echo "SKIPPED: SNS topic (insufficient permissions)"
            return
        fi
    fi

    aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$ALERT_EMAIL" &> /dev/null
    [ $? -eq 0 ] && echo "Email subscription created (check inbox)"

    cat > /tmp/budget.json <<EOF
{
  "BudgetName": "eshop-monthly-budget",
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY",
  "BudgetLimit": {
    "Amount": "100",
    "Unit": "USD"
  },
  "CostFilters": {},
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "IncludeRefund": false,
    "IncludeCredit": false,
    "IncludeUpfront": true,
    "IncludeRecurring": true,
    "IncludeOtherSubscription": true,
    "IncludeSupport": true,
    "IncludeDiscount": true,
    "UseAmortized": false
  }
}
EOF

    cat > /tmp/notifications.json <<EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 50,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "SNS",
        "Address": "$TOPIC_ARN"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "SNS",
        "Address": "$TOPIC_ARN"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "SNS",
        "Address": "$TOPIC_ARN"
      }
    ]
  }
]
EOF

    aws budgets create-budget \
        --account-id "$AWS_ACCOUNT_ID" \
        --budget file:///tmp/budget.json \
        --notifications-with-subscribers file:///tmp/notifications.json &> /dev/null

    if [ $? -eq 0 ]; then
        echo "Budget configured successfully"
        SETUP_STATUS[BUDGET]=true
    else
        echo "SKIPPED: Budget (insufficient permissions)"
    fi

    rm -f /tmp/budget.json /tmp/notifications.json
}

set_parameters() {
    aws ssm put-parameter --name "/eshop/dev/db-master-password" --value "$DB_PASSWORD" --type "SecureString" --description "RDS master password for dev environment" --overwrite &> /dev/null

    if [ $? -eq 0 ]; then
        aws ssm put-parameter --name "/eshop/dev/jwt-secret-key" --value "$JWT_SECRET" --type "SecureString" --description "JWT secret key for authentication" --overwrite &> /dev/null
        aws ssm put-parameter --name "/eshop/config/alert-email" --value "$ALERT_EMAIL" --type "String" --description "Email for infrastructure alerts" --overwrite &> /dev/null
        aws ssm put-parameter --name "/eshop/config/github-repo" --value "$GITHUB_REPO" --type "String" --description "GitHub repository for CI/CD" --overwrite &> /dev/null
        echo "Parameters stored in SSM Parameter Store"
        SETUP_STATUS[SSM]=true
    else
        echo "SKIPPED: SSM parameters (insufficient permissions)"
    fi
}

create_config_files() {
    cat > ../terraform/terraform-backend.tfvars <<EOF
bucket         = "$BUCKET_NAME"
key            = "eshop/dev/terraform.tfstate"
region         = "$AWS_REGION"
encrypt        = true
dynamodb_table = "eshop-terraform-locks"
EOF

    cat > ../terraform/terraform.tfvars <<EOF
aws_region         = "$AWS_REGION"
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["${AWS_REGION}a", "${AWS_REGION}b"]

rds_master_password = "$DB_PASSWORD"
jwt_secret_key      = "$JWT_SECRET"

alert_email = "$ALERT_EMAIL"

enable_cost_optimization = true
use_single_nat_gateway   = true
EOF

    cat > github-secrets.txt <<EOF
GitHub Secrets Configuration

Add these secrets to your GitHub repository:
Settings -> Secrets and variables -> Actions -> New repository secret

AWS_ROLE_ARN = $GITHUB_ROLE_ARN
AWS_REGION = $AWS_REGION
EOF

    cat > setup-summary.txt <<EOF
eShop AWS Setup Summary

Account ID: $AWS_ACCOUNT_ID
Region: $AWS_REGION
Terraform State Bucket: $BUCKET_NAME
GitHub Actions Role: $GITHUB_ROLE_ARN

Next Steps:
1. Check email ($ALERT_EMAIL) to confirm SNS subscription
2. Add GitHub secrets (see github-secrets.txt)
3. Deploy infrastructure:
   cd ../terraform
   terraform init -backend-config=terraform-backend.tfvars
   terraform plan
   terraform apply

Security Notes:
terraform.tfvars contains secrets - DO NOT commit to Git
Database password and JWT secret stored in Parameter Store
GitHub Actions uses OIDC (no long-lived credentials)

Cost Monitoring:
Budget alerts at 50%, 80%, 100% of \$100/month
Alerts sent to: $ALERT_EMAIL

Files Created:
terraform-backend.tfvars
terraform.tfvars
github-secrets.txt
setup-summary.txt
EOF

    echo "Configuration files created"
}

main() {
    test_aws_cli
    test_aws_credentials
    get_user_inputs

    echo ""
    echo "Configuring AWS resources..."
    echo ""

    create_terraform_state_bucket
    create_dynamodb_lock_table
    create_github_oidc
    create_cost_alerts
    set_parameters
    create_config_files

    echo ""
    echo "========================================"
    echo "Setup Status Summary"
    echo "========================================"

    [ "${SETUP_STATUS[S3]}" = true ] && echo "[OK] S3 Terraform State Bucket" || echo "[--] S3 Terraform State Bucket"
    [ "${SETUP_STATUS[DYNAMODB]}" = true ] && echo "[OK] DynamoDB Lock Table" || echo "[--] DynamoDB Lock Table"
    [ "${SETUP_STATUS[OIDC]}" = true ] && echo "[OK] GitHub OIDC Provider" || echo "[--] GitHub OIDC Provider"
    [ "${SETUP_STATUS[IAMROLE]}" = true ] && echo "[OK] GitHub Actions IAM Role" || echo "[--] GitHub Actions IAM Role"
    [ "${SETUP_STATUS[SNS]}" = true ] && echo "[OK] SNS Cost Alert Topic" || echo "[--] SNS Cost Alert Topic"
    [ "${SETUP_STATUS[BUDGET]}" = true ] && echo "[OK] Budget Alerts" || echo "[--] Budget Alerts"
    [ "${SETUP_STATUS[SSM]}" = true ] && echo "[OK] SSM Parameters" || echo "[--] SSM Parameters"

    echo ""
    echo "========================================"
    echo ""
    cat setup-summary.txt
}

main
