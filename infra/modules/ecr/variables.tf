variable "project" {
  type        = string
  description = "Project name used in repository names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "repository_names" {
  type        = list(string)
  description = "Names of the ECR repositories to create (for example api, worker, frontend)."
  default     = ["api", "worker", "frontend"]
}

variable "image_retention_count" {
  type        = number
  description = "Number of images to retain per repository."
  default     = 20
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
