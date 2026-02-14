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
