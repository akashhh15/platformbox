variable "project" {
  type        = string
  description = "Project name used in cluster names and tags."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster. Use a version in standard support."
  default     = "1.31"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the cluster and nodes."
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the public API endpoint."
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type        = list(string)
  description = "Instance types for the system node group."
  default     = ["t3.medium"]
}

variable "node_min_size" {
  type        = number
  description = "Minimum size of the system node group."
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum size of the system node group."
  default     = 4
}

variable "node_desired_size" {
  type        = number
  description = "Desired size of the system node group."
  default     = 2
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
