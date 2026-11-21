variable "project" {
  type        = string
  description = "Project name used in secret names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "secret_names" {
  type        = list(string)
  description = "Names of the Secrets Manager secrets to create. Values are never stored in Terraform state; they are populated out of band."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
