locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  role_name = var.role_name != "" ? var.role_name : "${var.project}-${var.environment}-${var.namespace}-${var.service_account_name}"

  # Strip the https:// prefix from the OIDC provider URL for use in the trust
  # policy subject condition.
  oidc_url = replace(var.oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "this" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "this" {
  count = var.policy_json != "" ? 1 : 0

  name   = "inline"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}
