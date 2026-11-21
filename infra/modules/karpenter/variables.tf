variable "project" {
  type        = string
  description = "Project name used in resource names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster Karpenter manages."
}

variable "cluster_endpoint" {
  type        = string
  description = "Endpoint of the EKS cluster."
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS IRSA OIDC provider."
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the EKS IRSA OIDC provider."
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
