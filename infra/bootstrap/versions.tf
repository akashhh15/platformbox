# Terraform and provider version constraints for the bootstrap root module.
# The bootstrap is applied once, locally, by the human. It creates the S3 state
# bucket, the GitHub and GitLab OIDC providers, the CI IAM roles and the budget.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
}
