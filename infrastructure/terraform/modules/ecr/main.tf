# ECR Repositories for Container Images

resource "aws_ecr_repository" "service" {
  for_each = toset(var.services)

  name                 = "${var.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allow deletion even with images present

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each = aws_ecr_repository.service

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
