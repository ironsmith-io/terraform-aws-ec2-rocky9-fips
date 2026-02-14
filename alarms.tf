#=============================================================================
# Security Alarms (conditional)
#=============================================================================

# SNS Topic for alarm notifications
resource "aws_sns_topic" "alarms" {
  count = var.create_sns_topic ? 1 : 0
  name  = "${var.name}-security-alarms"
  tags  = local.common_tags
}

# SNS Email subscription
resource "aws_sns_topic_subscription" "email" {
  count     = var.create_sns_topic && var.alarm_email != null ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Metric filter for failed SSH login attempts
resource "aws_cloudwatch_log_metric_filter" "failed_ssh" {
  count          = var.enable_security_alarms && var.enable_cloudwatch_logs ? 1 : 0
  name           = "${var.name}-failed-ssh"
  log_group_name = aws_cloudwatch_log_group.this[0].name
  pattern        = "?\"Failed password\" ?\"authentication failure\" ?\"Invalid user\""

  metric_transformation {
    name          = "FailedSSHAttempts"
    namespace     = "${var.name}/Security/${local.instance_id}"
    value         = "1"
    default_value = "0"
  }
}

# Alarm: Multiple failed SSH attempts
resource "aws_cloudwatch_metric_alarm" "failed_ssh" {
  count               = var.enable_security_alarms && var.enable_cloudwatch_logs ? 1 : 0
  alarm_name          = "${var.name}-failed-ssh-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedSSHAttempts"
  namespace           = "${var.name}/Security/${local.instance_id}"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Multiple failed SSH login attempts detected"
  alarm_actions       = local.alarm_sns_arn != null ? [local.alarm_sns_arn] : []
  treat_missing_data  = "notBreaching"
  tags                = local.common_tags
}

# Alarm: High disk usage
resource "aws_cloudwatch_metric_alarm" "disk_usage" {
  count               = var.enable_security_alarms && var.enable_cloudwatch_logs ? 1 : 0
  alarm_name          = "${var.name}-disk-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Disk usage exceeds 85%"
  alarm_actions       = local.alarm_sns_arn != null ? [local.alarm_sns_arn] : []
  ok_actions          = local.alarm_sns_arn != null ? [local.alarm_sns_arn] : []
  treat_missing_data  = "notBreaching"
  tags                = local.common_tags

  dimensions = {
    InstanceId = local.instance_id
    path       = "/"
    fstype     = "xfs"
  }
}

# Alarm: High CPU usage (sustained)
resource "aws_cloudwatch_metric_alarm" "cpu_usage" {
  count               = var.enable_security_alarms ? 1 : 0
  alarm_name          = "${var.name}-cpu-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "CPU usage exceeds 90% for 15 minutes"
  alarm_actions       = local.alarm_sns_arn != null ? [local.alarm_sns_arn] : []
  ok_actions          = local.alarm_sns_arn != null ? [local.alarm_sns_arn] : []
  treat_missing_data  = "notBreaching"
  tags                = local.common_tags

  dimensions = {
    InstanceId = local.instance_id
  }
}

# Alarm: Instance status check failed
resource "aws_cloudwatch_metric_alarm" "status_check" {
  count               = var.enable_security_alarms ? 1 : 0
  alarm_name          = "${var.name}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 instance status check failed"
  alarm_actions       = local.alarm_sns_arn != null ? [local.alarm_sns_arn] : []
  ok_actions          = local.alarm_sns_arn != null ? [local.alarm_sns_arn] : []
  treat_missing_data  = "breaching"
  tags                = local.common_tags

  dimensions = {
    InstanceId = local.instance_id
  }
}
