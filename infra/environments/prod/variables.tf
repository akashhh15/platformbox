variable "project" {
  type    = string
  default = "cloud-platform-in-a-box"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint. Restrict in prod."
  default     = []
}

variable "budget_email" {
  type        = string
  description = "Email for budget alerts."
}

variable "budget_limit_usd" {
  type    = number
  default = 200
}

variable "rds_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
