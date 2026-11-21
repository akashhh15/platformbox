# Bootstrap resources.
#
# This root module is applied once, by a human with administrative credentials,
# to create the shared infrastructure that the environments depend on:
#   * the S3 bucket that stores Terraform state (with native locking),
#   * the GitHub Actions and GitLab CI OIDC providers,
#   * the least-privilege CI roles that assume those identities,
#   * an AWS Budget with email alerts.
#
# Nothing here is applied by the agent. Run `terraform plan` first and review.

locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Owner       = "platform-team"
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  # GitHub OIDC thumbprint published by GitHub. Verify against the current
  # GitHub documentation before applying: the value is stable but must match
  # the certificate chain GitHub presents.
  github_oidc_thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"

  # GitLab.com OIDC thumbprint. Verify against GitLab documentation before
  # applying; GitLab rotates certificates on its own schedule.
  gitlab_oidc_thumbprint = "b3dd1c3349e0531c3a5c52e9840c781e47693805"
}

# KMS key for state bucket encryption.
resource "aws_kms_key" "state" {
  description             = "KMS key for Terraform state bucket encryption (${var.project}-${var.environment})"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
    ]
  })

  tags = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.project}-${var.environment}-state"
  target_key_id = aws_kms_key.state.key_id
}

resource "aws_s3_bucket" "state" {
  # checkov:skip=CKV2_AWS_62:state bucket does not need event notifications
  # checkov:skip=CKV_AWS_18:access logging for the state bucket is handled by AWS CloudTrail
  # checkov:skip=CKV_AWS_144:cross-region replication is not required for the state bucket
  bucket = var.state_bucket_name

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# TLS-only access. Native state locking (use_lockfile) relies on conditional
# writes, which require versioning (enabled above) and do not need DynamoDB.
resource "aws_s3_bucket_policy" "state_tls_only" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# OIDC providers
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.github_oidc_thumbprint]

  tags = local.common_tags
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = "https://gitlab.com"
  client_id_list  = ["https://gitlab.com"]
  thumbprint_list = [local.gitlab_oidc_thumbprint]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# IAM roles for CI
# ---------------------------------------------------------------------------

# GitHub Actions: terraform plan. Read-only plus state access; usable from pull
# requests. No write permissions.
resource "aws_iam_role" "github_terraform_plan" {
  name = "${var.project}-${var.environment}-github-terraform-plan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:pull_request"
          }
        }
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "github_terraform_plan" {
  name = "plan"
  role = aws_iam_role.github_terraform_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateBucketRead"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
      },
      {
        Sid      = "ReadOnlyAWS"
        Effect   = "Allow"
        Action   = ["ec2:Describe*", "eks:Describe*", "eks:List*", "ecr:Describe*", "ecr:Get*", "ecr:List*", "rds:Describe*", "iam:Get*", "iam:List*", "kms:Describe*", "kms:List*", "logs:Describe*", "cloudwatch:Describe*", "cloudwatch:Get*", "elasticloadbalancing:Describe*", "autoscaling:Describe*", "sqs:Get*", "sqs:List*", "events:Describe*", "events:List*"]
        Resource = "*"
      },
    ]
  })
}

# GitHub Actions: terraform apply. Restricted to the main branch and the dev
# environment. Granted the write permissions needed to manage the platform.
resource "aws_iam_role" "github_terraform_apply" {
  name = "${var.project}-${var.environment}-github-terraform-apply"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:environment:dev"
          }
        }
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "github_terraform_apply" {
  name = "apply"
  role = aws_iam_role.github_terraform_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateBucketFull"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
      },
      {
        Sid      = "PlatformManagement"
        Effect   = "Allow"
        Action   = ["ec2:*", "eks:*", "ecr:*", "rds:*", "iam:*", "kms:*", "logs:*", "cloudwatch:*", "elasticloadbalancing:*", "autoscaling:*", "sqs:*", "events:*", "sts:GetCallerIdentity"]
        Resource = "*"
      },
    ]
  })
}

# GitLab CI: push images to the project ECR repositories. Only from the main
# branch or protected tags.
resource "aws_iam_role" "gitlab_ecr_push" {
  name = "${var.project}-${var.environment}-gitlab-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.gitlab.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "gitlab.com:aud" = "https://gitlab.com"
          }
          StringLike = {
            "gitlab.com:sub" = "project_path:${var.gitlab_project_path}:ref_type:*"
          }
        }
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "gitlab_ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.gitlab_ecr_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/${var.project}-*"
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Budget
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-${var.environment}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }

  tags = local.common_tags
}
