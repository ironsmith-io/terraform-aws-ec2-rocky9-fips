output "instance_id" {
  value       = aws_instance.this.id
  description = "EC2 instance ID"
}

output "public_ip" {
  value       = aws_instance.this.public_ip
  description = "Public IP address (if assigned)"
}

output "private_ip" {
  value       = aws_instance.this.private_ip
  description = "Private IP address"
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Security group ID"
}

output "iam_role_arn" {
  value       = local.use_instance_profile ? aws_iam_role.this[0].arn : null
  description = "IAM role ARN (when instance profile is created)"
}

output "ami_id" {
  value       = local.ami_id
  description = "AMI ID used for the instance (useful when auto-discovered)"
}

output "ami_name" {
  value       = data.aws_ami.rocky9_fips.name
  description = "AMI name (from data source)"
}

output "ssh_command" {
  value       = aws_instance.this.public_ip != null ? "ssh rocky@${aws_instance.this.public_ip}" : null
  description = "SSH command to connect to the instance"
}

output "cloudwatch_log_group_name" {
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.this[0].name : null
  description = "CloudWatch Log Group name (when CloudWatch is enabled)"
}

output "cloudwatch_dashboard_url" {
  value       = var.enable_cloudwatch_logs ? "https://${data.aws_region.current.id}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#dashboards:name=${aws_cloudwatch_dashboard.this[0].dashboard_name}" : null
  description = "CloudWatch Operations Dashboard URL (when CloudWatch is enabled)"
}

output "sns_topic_arn" {
  value       = var.create_sns_topic ? aws_sns_topic.alarms[0].arn : null
  description = "SNS Topic ARN for alarm notifications (when create_sns_topic is true)"
}
