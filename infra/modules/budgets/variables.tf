variable "project" {
  type        = string
  description = "Project name used in budget names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "budget_email" {
  type        = string
  description = "Email address that receives budget alerts."
}

variable "budget_limit_usd" {
  type        = number
  description = "Monthly budget limit in USD."
  default     = 50
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
