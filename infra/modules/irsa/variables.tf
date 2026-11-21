variable "project" {
  type        = string
  description = "Project name used in role names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS IRSA OIDC provider."
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the EKS IRSA OIDC provider (without https://)."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the service account."
}

variable "service_account_name" {
  type        = string
  description = "Name of the Kubernetes service account."
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role to create. Defaults to a derived name."
  default     = ""
}

variable "policy_json" {
  type        = string
  description = "IAM policy document JSON to attach to the role."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
