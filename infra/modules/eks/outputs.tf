output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS Kubernetes API."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the IRSA OIDC provider."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the IRSA OIDC provider."
  value       = module.eks.oidc_provider
}

output "node_security_group_id" {
  description = "Security group ID of the EKS nodes."
  value       = module.eks.node_security_group_id
}

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster control plane."
  value       = module.eks.cluster_security_group_id
}
