output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  description = "ECR repository URLs."
  value       = module.ecr.repository_urls
}

output "rds_endpoint" {
  description = "RDS endpoint (if enabled)."
  value       = module.rds.endpoint
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN for Karpenter-launched nodes; set on the Argo CD cluster Secret."
  value       = module.karpenter.node_role_arn
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue used for Karpenter spot and scheduled-change interruptions."
  value       = module.karpenter.interruption_queue_name
}
