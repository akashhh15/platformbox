variable "project" {
  type        = string
  description = "Project name."
  default     = "cloud-platform-in-a-box"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region."
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint."
  default     = ["0.0.0.0/0"]
}

variable "budget_email" {
  type        = string
  description = "Email for budget alerts."
}

variable "budget_limit_usd" {
  type    = number
  default = 50
}

variable "rds_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
