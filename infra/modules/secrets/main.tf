locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager (${var.project}-${var.environment})"
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

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# console; External Secrets Operator then syncs them into the cluster. No secret
# value ever appears in Terraform code or state.
resource "aws_secretsmanager_secret" "this" {
  # checkov:skip=CKV2_AWS_57:rotation is configured after the secret value is populated by a human
  for_each = toset(var.secret_names)

  name        = "${var.project}/${var.environment}/${each.value}"
  description = "Managed by Terraform for ${var.project} (${var.environment})."
  kms_key_id  = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, { Name = "${var.project}/${var.environment}/${each.value}" })
}
