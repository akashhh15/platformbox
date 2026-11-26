terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  # Backend is configured at init time to avoid hardcoding the bucket name:
  #   terraform init -backend-config="bucket=<state-bucket>" \
  #                  -backend-config="key=dev/terraform.tfstate" \
  #                  -backend-config="region=ap-south-1" \
  #                  -backend-config="use_lockfile=true"
  backend "s3" {}
}
