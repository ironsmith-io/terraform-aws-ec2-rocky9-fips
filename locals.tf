locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.rocky9_fips.id
  # ami_id = "ami-06d463b02f7b8481e"
  # ami_id = "ami-080017c6a6a51b70b"
  use_instance_profile = (
    length(var.aws_iam_policy_arns) > 0 ||
    var.enable_cloudwatch_logs ||
    var.enable_ssm
  )

  instance_id = aws_instance.this.id

  # CloudWatch log group name (includes var.name to avoid collisions)
  log_group_name             = "/${var.name}/ec2"
  log_group_name_url_encoded = replace(local.log_group_name, "/", "$252F")

  # ARN partition (supports aws, aws-us-gov, aws-cn)
  partition = data.aws_partition.current.partition

  common_tags = merge(
    {
      Name      = var.name
      ManagedBy = "terraform"
      Module    = "terraform-aws-ec2-rocky9-fips"
      OS        = "Rocky Linux 9"
      FIPS      = "enabled"
    },
    var.tags
  )

  # SNS topic ARN (use created topic or provided ARN)
  alarm_sns_arn = var.create_sns_topic ? (length(aws_sns_topic.alarms) > 0 ? aws_sns_topic.alarms[0].arn : null) : var.alarm_sns_topic_arn
}
