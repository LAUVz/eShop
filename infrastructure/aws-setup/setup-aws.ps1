#Requires -Version 5.1

$ErrorActionPreference = "Stop"
$script:SetupStatus = @{
    S3Bucket = $false
    DynamoDB = $false
    OIDC = $false
    IAMRole = $false
    SNSTopic = $false
    Budget = $false
    SSMParams = $false
}

function Test-AwsCli {
    try {
        $null = aws --version
        Write-Host "AWS CLI installed"
        return $true
    }
    catch {
        Write-Host "ERROR: AWS CLI not installed" -ForegroundColor Red
        Write-Host "Install from: https://awscli.amazonaws.com/AWSCLIV2.msi"
        return $false
    }
}

function Test-AwsCredentials {
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        $script:AWS_ACCOUNT_ID = $identity.Account
        Write-Host "AWS Account ID: $AWS_ACCOUNT_ID"
        return $true
    }
    catch {
        Write-Host "ERROR: AWS credentials not configured" -ForegroundColor Red
        Write-Host "Run: aws configure"
        return $false
    }
}

function Get-UserInputs {
    $configFile = "setup-config.json"
    $savedConfig = $null

    if (Test-Path $configFile) {
        try {
            $savedConfig = Get-Content $configFile -Raw | ConvertFrom-Json
            Write-Host "Found saved configuration from previous run"
        }
        catch {
            $savedConfig = $null
        }
    }

    do {
        $defaultEmail = if ($savedConfig) { $savedConfig.ALERT_EMAIL } else { "" }
        $prompt = if ($defaultEmail) { "Email for cost alerts [$defaultEmail]" } else { "Email for cost alerts" }
        $emailInput = Read-Host $prompt
        $script:ALERT_EMAIL = if ($emailInput) { $emailInput } else { $defaultEmail }

        $emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`$"
        if ($ALERT_EMAIL -notmatch $emailRegex) {
            Write-Host "Invalid email format" -ForegroundColor Red
        }
    } while ($ALERT_EMAIL -notmatch $emailRegex)

    do {
        $defaultRepo = if ($savedConfig) { $savedConfig.GITHUB_REPO } else { "" }
        $prompt = if ($defaultRepo) { "GitHub repository (format: username/repo) [$defaultRepo]" } else { "GitHub repository (format: username/repo)" }
        $repoInput = Read-Host $prompt
        $script:GITHUB_REPO = if ($repoInput) { $repoInput } else { $defaultRepo }

        $repoRegex = "^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$"
        if ($GITHUB_REPO -notmatch $repoRegex) {
            Write-Host "Invalid format. Expected: username/repo-name" -ForegroundColor Red
        }
    } while ($GITHUB_REPO -notmatch $repoRegex)

    $defaultRegion = if ($savedConfig) { $savedConfig.AWS_REGION } else { "us-east-1" }
    $regionInput = Read-Host "AWS region [$defaultRegion]"
    $script:AWS_REGION = if ($regionInput) { $regionInput } else { $defaultRegion }
    $env:AWS_DEFAULT_REGION = $AWS_REGION

    $config = @{
        ALERT_EMAIL = $ALERT_EMAIL
        GITHUB_REPO = $GITHUB_REPO
        AWS_REGION = $AWS_REGION
    } | ConvertTo-Json

    $config | Out-File -FilePath $configFile -Encoding utf8

    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($bytes)
    $script:DB_PASSWORD = [Convert]::ToBase64String($bytes) -replace '[+/=]','' | Select-Object -First 32

    $bytes = New-Object byte[] 64
    $rng.GetBytes($bytes)
    $script:JWT_SECRET = [Convert]::ToBase64String($bytes) -replace '[+/=]','' | Select-Object -First 64
}

function New-TerraformStateBucket {
    $script:BUCKET_NAME = "eshop-terraform-state-$AWS_ACCOUNT_ID"

    try {
        $null = aws s3 ls "s3://$BUCKET_NAME" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "S3 bucket exists: $BUCKET_NAME"
            $script:SetupStatus.S3Bucket = $true
            return
        }
    }
    catch {}

    try {
        Write-Host "Creating S3 bucket: $BUCKET_NAME"

        if ($AWS_REGION -eq "us-east-1") {
            $null = aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION 2>&1
        }
        else {
            $null = aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            $null = aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled 2>&1

            $encryptionConfig = @{
                Rules = @(
                    @{
                        ApplyServerSideEncryptionByDefault = @{
                            SSEAlgorithm = "AES256"
                        }
                    }
                )
            } | ConvertTo-Json -Depth 10

            $encryptionFile = "$env:TEMP\encryption.json"
            [System.IO.File]::WriteAllText($encryptionFile, $encryptionConfig, [System.Text.UTF8Encoding]::new($false))
            $null = aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration "file://$encryptionFile" 2>&1
            Remove-Item $encryptionFile -ErrorAction SilentlyContinue
            $null = aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true 2>&1

            Write-Host "S3 bucket created successfully"
            $script:SetupStatus.S3Bucket = $true
        }
        else {
            Write-Host "SKIPPED: S3 bucket (insufficient permissions)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "SKIPPED: S3 bucket (insufficient permissions)" -ForegroundColor Yellow
    }
}

function New-DynamoDBLockTable {
    $TABLE_NAME = "eshop-terraform-locks"

    try {
        $null = aws dynamodb describe-table --table-name $TABLE_NAME 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "DynamoDB table exists: $TABLE_NAME"
            $script:SetupStatus.DynamoDB = $true
            return
        }
    }
    catch {}

    try {
        Write-Host "Creating DynamoDB table: $TABLE_NAME"

        $null = aws dynamodb create-table `
            --table-name $TABLE_NAME `
            --attribute-definitions AttributeName=LockID,AttributeType=S `
            --key-schema AttributeName=LockID,KeyType=HASH `
            --billing-mode PAY_PER_REQUEST `
            --region $AWS_REGION 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "DynamoDB table created successfully"
            $script:SetupStatus.DynamoDB = $true
        }
        else {
            Write-Host "SKIPPED: DynamoDB table (insufficient permissions)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "SKIPPED: DynamoDB table (insufficient permissions)" -ForegroundColor Yellow
    }
}

function New-GitHubOIDC {
    $PROVIDER_ARN = "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

    try {
        $null = aws iam get-open-id-connect-provider --open-id-connect-provider-arn $PROVIDER_ARN 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OIDC provider exists"
            $script:SetupStatus.OIDC = $true
        }
    }
    catch {
        Write-Host "Creating OIDC provider"
        $null = aws iam create-open-id-connect-provider `
            --url https://token.actions.githubusercontent.com `
            --client-id-list sts.amazonaws.com `
            --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 2>&1

        if ($LASTEXITCODE -eq 0) {
            $script:SetupStatus.OIDC = $true
        }
    }

    $trustPolicy = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Effect = "Allow"
                Principal = @{
                    Federated = $PROVIDER_ARN
                }
                Action = "sts:AssumeRoleWithWebIdentity"
                Condition = @{
                    StringEquals = @{
                        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
                    }
                    StringLike = @{
                        "token.actions.githubusercontent.com:sub" = "repo:${GITHUB_REPO}:*"
                    }
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    $trustPolicyFile = "$env:TEMP\github-trust-policy.json"
    [System.IO.File]::WriteAllText($trustPolicyFile, $trustPolicy, [System.Text.UTF8Encoding]::new($false))

    $ROLE_NAME = "GitHubActionsRole"

    try {
        $null = aws iam get-role --role-name $ROLE_NAME 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "IAM role exists: $ROLE_NAME"
            $script:SetupStatus.IAMRole = $true
        }
    }
    catch {
        Write-Host "Creating IAM role: $ROLE_NAME"
        $null = aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document "file://$trustPolicyFile" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $null = aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>&1
            $script:SetupStatus.IAMRole = $true
        }
    }

    $script:GITHUB_ROLE_ARN = aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text 2>&1

    Remove-Item $trustPolicyFile -ErrorAction SilentlyContinue
}

function New-CostAlerts {
    $TOPIC_NAME = "eshop-cost-alerts"
    $script:TOPIC_ARN = $null

    try {
        $result = aws sns create-topic --name $TOPIC_NAME --output json 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $topicData = $result | ConvertFrom-Json
            $script:TOPIC_ARN = $topicData.TopicArn
            Write-Host "SNS topic created: $TOPIC_ARN"
            $script:SetupStatus.SNSTopic = $true
        }
    }
    catch {}

    if ($TOPIC_ARN) {
        $null = aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint $ALERT_EMAIL 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Email subscription created (check inbox)"
        }
    }
    else {
        Write-Host "SKIPPED: SNS topic (insufficient permissions)" -ForegroundColor Yellow
    }

    $budget = @{
        BudgetName = "eshop-monthly-budget"
        BudgetType = "COST"
        TimeUnit = "MONTHLY"
        BudgetLimit = @{
            Amount = "100"
            Unit = "USD"
        }
        CostFilters = @{}
        CostTypes = @{
            IncludeTax = $true
            IncludeSubscription = $true
            UseBlended = $false
            IncludeRefund = $false
            IncludeCredit = $false
            IncludeUpfront = $true
            IncludeRecurring = $true
            IncludeOtherSubscription = $true
            IncludeSupport = $true
            IncludeDiscount = $true
            UseAmortized = $false
        }
    } | ConvertTo-Json -Depth 10

    $notifications = @(
        @{
            Notification = @{
                NotificationType = "ACTUAL"
                ComparisonOperator = "GREATER_THAN"
                Threshold = 50
                ThresholdType = "PERCENTAGE"
            }
            Subscribers = @(
                @{
                    SubscriptionType = "SNS"
                    Address = $TOPIC_ARN
                }
            )
        },
        @{
            Notification = @{
                NotificationType = "ACTUAL"
                ComparisonOperator = "GREATER_THAN"
                Threshold = 80
                ThresholdType = "PERCENTAGE"
            }
            Subscribers = @(
                @{
                    SubscriptionType = "SNS"
                    Address = $TOPIC_ARN
                }
            )
        },
        @{
            Notification = @{
                NotificationType = "FORECASTED"
                ComparisonOperator = "GREATER_THAN"
                Threshold = 100
                ThresholdType = "PERCENTAGE"
            }
            Subscribers = @(
                @{
                    SubscriptionType = "SNS"
                    Address = $TOPIC_ARN
                }
            )
        }
    ) | ConvertTo-Json -Depth 10

    $budgetFile = "$env:TEMP\budget.json"
    $notificationsFile = "$env:TEMP\notifications.json"

    [System.IO.File]::WriteAllText($budgetFile, $budget, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($notificationsFile, $notifications, [System.Text.UTF8Encoding]::new($false))

    if ($TOPIC_ARN) {
        try {
            $null = aws budgets create-budget --account-id $AWS_ACCOUNT_ID --budget "file://$budgetFile" --notifications-with-subscribers "file://$notificationsFile" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Budget configured successfully"
                $script:SetupStatus.Budget = $true
            }
            else {
                Write-Host "SKIPPED: Budget (insufficient permissions)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "SKIPPED: Budget (insufficient permissions)" -ForegroundColor Yellow
        }
    }

    Remove-Item $budgetFile, $notificationsFile -ErrorAction SilentlyContinue
}

function Set-Parameters {
    $null = aws ssm put-parameter --name "/eshop/dev/db-master-password" --value $DB_PASSWORD --type "SecureString" --description "RDS master password for dev environment" --overwrite 2>&1
    if ($LASTEXITCODE -eq 0) {
        $null = aws ssm put-parameter --name "/eshop/dev/jwt-secret-key" --value $JWT_SECRET --type "SecureString" --description "JWT secret key for authentication" --overwrite 2>&1
        $null = aws ssm put-parameter --name "/eshop/config/alert-email" --value $ALERT_EMAIL --type "String" --description "Email for infrastructure alerts" --overwrite 2>&1
        $null = aws ssm put-parameter --name "/eshop/config/github-repo" --value $GITHUB_REPO --type "String" --description "GitHub repository for CI/CD" --overwrite 2>&1
        Write-Host "Parameters stored in SSM Parameter Store"
        $script:SetupStatus.SSMParams = $true
    }
    else {
        Write-Host "SKIPPED: SSM parameters (insufficient permissions)" -ForegroundColor Yellow
    }
}

function New-ConfigFiles {
    $backendConfig = @"
bucket         = "$BUCKET_NAME"
key            = "eshop/dev/terraform.tfstate"
region         = "$AWS_REGION"
encrypt        = true
dynamodb_table = "eshop-terraform-locks"
"@

    $backendConfig | Out-File -FilePath "..\terraform\terraform-backend.tfvars" -Encoding utf8

    $tfVars = @"
aws_region         = "$AWS_REGION"
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["${AWS_REGION}a", "${AWS_REGION}b"]

rds_master_password = "$DB_PASSWORD"
jwt_secret_key      = "$JWT_SECRET"

alert_email = "$ALERT_EMAIL"

enable_cost_optimization = true
use_single_nat_gateway   = true
"@

    $tfVars | Out-File -FilePath "..\terraform\terraform.tfvars" -Encoding utf8

    $githubSecrets = @"
GitHub Secrets Configuration

Add these secrets to your GitHub repository:
Settings -> Secrets and variables -> Actions -> New repository secret

AWS_ROLE_ARN = $GITHUB_ROLE_ARN
AWS_REGION = $AWS_REGION
"@

    $githubSecrets | Out-File -FilePath "github-secrets.txt" -Encoding utf8

    $summary = @"
eShop AWS Setup Summary

Account ID: $AWS_ACCOUNT_ID
Region: $AWS_REGION
Terraform State Bucket: $BUCKET_NAME
GitHub Actions Role: $GITHUB_ROLE_ARN

Next Steps:
1. Check email ($ALERT_EMAIL) to confirm SNS subscription
2. Add GitHub secrets (see github-secrets.txt)
3. Deploy infrastructure:
   cd ..\terraform
   terraform init -backend-config=\"terraform-backend.tfvars\"
   terraform plan
   terraform apply

Security Notes:
terraform.tfvars contains secrets - DO NOT commit to Git
Database password and JWT secret stored in Parameter Store
GitHub Actions uses OIDC (no long-lived credentials)

Cost Monitoring:
Budget alerts at 50%, 80%, 100% of `$100/month
Alerts sent to: $ALERT_EMAIL

Files Created:
terraform-backend.tfvars
terraform.tfvars
github-secrets.txt
setup-summary.txt
"@

    $summary | Out-File -FilePath "setup-summary.txt" -Encoding utf8
    Write-Host "Configuration files created"
}

function Main {
    if (-not (Test-AwsCli)) { exit 1 }
    if (-not (Test-AwsCredentials)) { exit 1 }

    Get-UserInputs

    Write-Host "`nConfiguring AWS resources...`n"

    New-TerraformStateBucket
    New-DynamoDBLockTable
    New-GitHubOIDC
    New-CostAlerts
    Set-Parameters
    New-ConfigFiles

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Setup Status Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $statusSymbol = @{ $true = "[OK]"; $false = "[--]" }
    Write-Host "$($statusSymbol[$SetupStatus.S3Bucket]) S3 Terraform State Bucket"
    Write-Host "$($statusSymbol[$SetupStatus.DynamoDB]) DynamoDB Lock Table"
    Write-Host "$($statusSymbol[$SetupStatus.OIDC]) GitHub OIDC Provider" -ForegroundColor $(if($SetupStatus.OIDC){"Green"}else{"Yellow"})
    Write-Host "$($statusSymbol[$SetupStatus.IAMRole]) GitHub Actions IAM Role" -ForegroundColor $(if($SetupStatus.IAMRole){"Green"}else{"Yellow"})
    Write-Host "$($statusSymbol[$SetupStatus.SNSTopic]) SNS Cost Alert Topic"
    Write-Host "$($statusSymbol[$SetupStatus.Budget]) Budget Alerts"
    Write-Host "$($statusSymbol[$SetupStatus.SSMParams]) SSM Parameters"

    Write-Host "`n========================================`n" -ForegroundColor Cyan
    Get-Content "setup-summary.txt"
}

Main
