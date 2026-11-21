output "secret_arns" {
  description = "Map of secret name to ARN."
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "secret_names" {
  description = "List of created secret names."
  value       = [for k, v in aws_secretsmanager_secret.this : v.name]
}
