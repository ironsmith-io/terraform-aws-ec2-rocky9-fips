output "instance_id" {
  value = module.rocky9_fips.instance_id
}

output "public_ip" {
  value = module.rocky9_fips.public_ip
}

output "private_ip" {
  value = module.rocky9_fips.private_ip
}

output "ssh_command" {
  value = module.rocky9_fips.ssh_command
}

output "ami_id" {
  value = module.rocky9_fips.ami_id
}

output "ami_name" {
  value = module.rocky9_fips.ami_name
}

output "security_group_id" {
  value = module.rocky9_fips.security_group_id
}

output "iam_role_arn" {
  value = module.rocky9_fips.iam_role_arn
}

output "cloudwatch_dashboard_url" {
  value = module.rocky9_fips.cloudwatch_dashboard_url
}

output "cloudwatch_log_group_name" {
  value = module.rocky9_fips.cloudwatch_log_group_name
}

output "sns_topic_arn" {
  value = module.rocky9_fips.sns_topic_arn
}
