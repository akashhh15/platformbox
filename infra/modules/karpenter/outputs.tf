output "controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role."
  value       = aws_iam_role.controller.arn
}

output "node_role_arn" {
  description = "ARN of the Karpenter node IAM role."
  value       = aws_iam_role.node.arn
}

output "node_instance_profile_name" {
  description = "Name of the Karpenter node instance profile."
  value       = aws_iam_instance_profile.node.name
}

output "interruption_queue_name" {
  description = "Name of the SQS interruption queue."
  value       = aws_sqs_queue.interruption.name
}

output "interruption_queue_arn" {
  description = "ARN of the SQS interruption queue."
  value       = aws_sqs_queue.interruption.arn
}
