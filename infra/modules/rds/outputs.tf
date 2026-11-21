output "endpoint" {
  description = "RDS endpoint (host:port). Empty if disabled."
  value       = var.enabled ? aws_db_instance.this[0].endpoint : ""
}

output "address" {
  description = "RDS hostname. Empty if disabled."
  value       = var.enabled ? aws_db_instance.this[0].address : ""
}

output "port" {
  description = "RDS port."
  value       = var.enabled ? aws_db_instance.this[0].port : 0
}

output "security_group_id" {
  description = "Security group ID of the RDS instance."
  value       = var.enabled ? aws_security_group.this[0].id : ""
}
