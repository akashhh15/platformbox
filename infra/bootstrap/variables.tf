# Variables for the bootstrap root module.
# Every value a human must supply is a variable with a clear name and a default
# only where a sensible default exists.

variable "project" {
  type        = string
  description = "Project name used in resource names and tags."
  default     = "platformbox"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "project must be lowercase alphanumeric with hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name for the bootstrap resources."
  default     = "bootstrap"

  validation {
    condition     = contains(["bootstrap", "dev", "prod"], var.environment)
    error_message = "environment must be one of bootstrap, dev, prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique name of the S3 bucket that holds Terraform state. Must be globally unique across all AWS accounts."
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user that owns the repository."
  default     = "akashhh15"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name."
  default     = "platformbox"
}

variable "gitlab_project_path" {
  type        = string
  description = "Full GitLab project path, for example group/cloud-platform-in-a-box."
  default     = "REPLACE_ME_GITLAB_GROUP/platformbox"
}

variable "budget_email" {
  type        = string
  description = "Email address that receives AWS Budget alerts."
}

variable "budget_limit_usd" {
  type        = number
  description = "Monthly budget limit in USD."
  default     = 50
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to every resource."
  default     = {}
}
