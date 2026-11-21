variable "project" {
  type        = string
  description = "Project name used in resource names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "enabled" {
  type        = bool
  description = "Whether to create the RDS instance. Toggle for cost control."
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group."
}

variable "node_security_group_id" {
  type        = string
  description = "Security group ID of the EKS nodes; RDS ingress is restricted to it."
}

variable "instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB."
  default     = 20
}

variable "database_name" {
  type        = string
  description = "Name of the initial database."
  default     = "app"
}

variable "master_username" {
  type        = string
  description = "Master username."
  default     = "appadmin"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
