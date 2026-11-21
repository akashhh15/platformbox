output "state_bucket_name" {
  description = "Name of the S3 bucket that holds Terraform state."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the S3 state bucket."
  value       = aws_s3_bucket.state.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "gitlab_oidc_provider_arn" {
  description = "ARN of the GitLab CI OIDC provider."
  value       = aws_iam_openid_connect_provider.gitlab.arn
}

output "github_terraform_plan_role_arn" {
  description = "ARN of the read-only terraform plan role for GitHub Actions."
  value       = aws_iam_role.github_terraform_plan.arn
}

output "github_terraform_apply_role_arn" {
  description = "ARN of the terraform apply role for GitHub Actions (main branch, dev environment)."
  value       = aws_iam_role.github_terraform_apply.arn
}

output "gitlab_ecr_push_role_arn" {
  description = "ARN of the ECR push role for GitLab CI."
  value       = aws_iam_role.gitlab_ecr_push.arn
}
