
# Rocky Linux 9 FIPS EC2 instance
resource "aws_instance" "this" {
  ami                     = local.ami_id
  key_name                = var.key_pair_name
  instance_type           = var.instance_type
  vpc_security_group_ids  = concat([aws_security_group.this.id], var.additional_security_group_ids)
  subnet_id               = var.subnet_id
  tags                    = local.common_tags
  iam_instance_profile    = local.use_instance_profile ? aws_iam_instance_profile.this[0].name : null
  disable_api_termination = var.enable_termination_protection

  user_data = templatefile("${path.module}/cloud-init.yml", {
    enable_cloudwatch_logs = var.enable_cloudwatch_logs
    enable_ssm             = var.enable_ssm
    enable_ssh             = var.enable_ssh
    user_data_extra        = var.user_data_extra
    log_group_name         = local.log_group_name
  })

  # Spot instance configuration (conditional)
  dynamic "instance_market_options" {
    for_each = var.create_spot_instance ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = var.delete_volume_on_termination
    encrypted             = true
    tags                  = local.common_tags
  }

  # Prevent accidental instance replacement when user_data variables change
  # To force replacement: terraform taint module.rocky9_fips.aws_instance.this
  lifecycle {
    ignore_changes = [user_data]
  }
}

#=============================================================================
# Security Group
#=============================================================================

resource "aws_security_group" "this" {
  name        = "${var.name}-ec2"
  description = "Security group for Rocky 9 FIPS instance"
  vpc_id      = data.aws_subnet.selected.vpc_id
  tags        = local.common_tags

  # SSH access (conditional)
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "TCP"
      description = "Allow SSH access"
      cidr_blocks = var.ip_allow_ssh
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow all outbound traffic"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#=============================================================================
# IAM (conditional)
#=============================================================================

resource "aws_iam_instance_profile" "this" {
  count = local.use_instance_profile ? 1 : 0
  name  = "${var.name}-instance-profile"
  role  = aws_iam_role.this[count.index].name
  tags  = local.common_tags
}

resource "aws_iam_role" "this" {
  count = local.use_instance_profile ? 1 : 0
  name  = "${var.name}-role"
  tags  = local.common_tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach custom managed policies
resource "aws_iam_role_policy_attachment" "managed" {
  count      = length(var.aws_iam_policy_arns)
  role       = aws_iam_role.this[0].name
  policy_arn = var.aws_iam_policy_arns[count.index]
}

#=============================================================================
# SSM Session Manager (conditional)
#=============================================================================

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#=============================================================================
# CloudWatch Logs (conditional)
#=============================================================================

resource "aws_cloudwatch_log_group" "this" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id
  tags              = local.common_tags
}

# IAM policy for CloudWatch agent (logs + metrics)
resource "aws_iam_role_policy" "cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.name}-cloudwatch"
  role  = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.this[0].arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = ["CWAgent", "Security"]
          }
        }
      }
    ]
  })
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "this" {
  count          = var.enable_cloudwatch_logs ? 1 : 0
  dashboard_name = "${var.name}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 3
        properties = {
          markdown = <<-EOT
## Rocky 9 FIPS - Operations Dashboard
**Instance:** ${local.instance_id} | **FIPS:** Enabled | **SSH:** `ssh rocky@${aws_instance.this.public_ip}`
**Links:** [EC2 Console](https://${data.aws_region.current.id}.console.aws.amazon.com/ec2/home?region=${data.aws_region.current.id}#InstanceDetails:instanceId=${local.instance_id}) | [CloudWatch Logs](https://${data.aws_region.current.id}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#logsV2:log-groups/log-group/${local.log_group_name_url_encoded})
EOT
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 3
        width  = 8
        height = 6
        properties = {
          title  = "CPU Utilization"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", local.instance_id]
          ]
          period = 300
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 3
        width  = 8
        height = 6
        properties = {
          title  = "Memory Used %"
          region = data.aws_region.current.id
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", local.instance_id]
          ]
          period = 300
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 3
        width  = 8
        height = 6
        properties = {
          title  = "Disk Used %"
          region = data.aws_region.current.id
          metrics = [
            ["CWAgent", "disk_used_percent", "InstanceId", local.instance_id, "path", "/", "fstype", "xfs"]
          ]
          period = 300
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 9
        width  = 12
        height = 6
        properties = {
          title  = "Network Traffic"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", local.instance_id],
            ["AWS/EC2", "NetworkOut", "InstanceId", local.instance_id]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 9
        width  = 12
        height = 6
        properties = {
          title  = "Status Check Failed"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", local.instance_id],
            ["AWS/EC2", "StatusCheckFailed_Instance", "InstanceId", local.instance_id],
            ["AWS/EC2", "StatusCheckFailed_System", "InstanceId", local.instance_id]
          ]
          period = 300
          stat   = "Maximum"
          yAxis = {
            left = { min = 0, max = 1 }
          }
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 15
        width  = 24
        height = 6
        properties = {
          title  = "Recent Log Activity"
          region = data.aws_region.current.id
          query  = "SOURCE '${local.log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}

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

#=============================================================================
# EBS Snapshots via Data Lifecycle Manager (conditional)
#=============================================================================

resource "aws_iam_role" "dlm" {
  count = var.enable_ebs_snapshots ? 1 : 0
  name  = "${var.name}-dlm-lifecycle-role"
  tags  = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "dlm" {
  count = var.enable_ebs_snapshots ? 1 : 0
  name  = "${var.name}-dlm-lifecycle-policy"
  role  = aws_iam_role.dlm[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:${local.partition}:ec2:*::snapshot/*"
      }
    ]
  })
}

resource "aws_dlm_lifecycle_policy" "this" {
  count              = var.enable_ebs_snapshots ? 1 : 0
  description        = "${var.name} EBS snapshot policy"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"
  tags               = local.common_tags

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "Daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.snapshot_time]
      }

      retain_rule {
        count = var.snapshot_retention_days
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Application     = var.name
      }

      copy_tags = true
    }

    target_tags = {
      Name = var.name
    }
  }
}

#=============================================================================
# Validation Checks (Terraform 1.5+)
#=============================================================================

check "remote_access_required" {
  assert {
    condition     = var.enable_ssh || var.enable_ssm
    error_message = "At least one of enable_ssh or enable_ssm must be true for remote access."
  }
}

check "ssh_requires_key_pair" {
  assert {
    condition     = !var.enable_ssh || var.key_pair_name != null
    error_message = "key_pair_name is required when enable_ssh = true."
  }
}

check "security_alarms_require_cloudwatch" {
  assert {
    condition     = !var.enable_security_alarms || var.enable_cloudwatch_logs
    error_message = "enable_security_alarms requires enable_cloudwatch_logs = true."
  }
}

check "sns_topic_requires_alarms" {
  assert {
    condition     = !var.create_sns_topic || var.enable_security_alarms
    error_message = "create_sns_topic is only useful with enable_security_alarms = true."
  }
}

check "alarm_email_requires_sns_topic" {
  assert {
    condition     = var.alarm_email == null || var.create_sns_topic || var.alarm_sns_topic_arn != null
    error_message = "alarm_email requires create_sns_topic = true or alarm_sns_topic_arn to be set."
  }
}

check "kms_key_requires_cloudwatch" {
  assert {
    condition     = var.cloudwatch_kms_key_id == null || var.enable_cloudwatch_logs
    error_message = "cloudwatch_kms_key_id is only used when enable_cloudwatch_logs = true."
  }
}
