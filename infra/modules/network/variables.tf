variable "project" {
  type        = string
  description = "Project name used in resource names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to use."
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single NAT gateway instead of one per AZ. Cheaper for dev; HA for prod."
  default     = true
}

variable "enable_flow_logs" {
  type        = bool
  description = "Enable VPC flow logs to CloudWatch."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to every resource."
  default     = {}
}
