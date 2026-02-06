#=============================================================================
# Required Variables
#=============================================================================

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the EC2 instance into. VPC is derived automatically."
  validation {
    condition     = can(regex("^subnet-[a-f0-9]{8,17}$", var.subnet_id))
    error_message = "Invalid AWS Subnet ID format (must be subnet-xxxxxxxx)."
  }
}

variable "key_pair_name" {
  type        = string
  default     = null
  description = "EC2 key pair name for SSH access. Required when enable_ssh = true."
}

#=============================================================================
# Instance Configuration
#=============================================================================

variable "ami_id" {
  type        = string
  default     = null
  description = "Specific AMI ID to use. If null, auto-discovers the latest ironsmith Rocky 9 FIPS AMI."
}

variable "ami_owner" {
  type        = string
  default     = "aws-marketplace"
  description = "AMI owner. Use 'aws-marketplace' for the public Marketplace AMI, or an account ID for private copies."
}

variable "ami_product_code" {
  type        = string
  default     = "5fbnogz030e3m2ddf2yvlqhho"
  description = "AWS Marketplace product code for the ironsmith Rocky 9 FIPS AMI"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type"
  validation {
    condition     = can(regex("^([a-z]+\\d+[a-z]*\\.[a-z0-9]+)$", var.instance_type))
    error_message = "Invalid EC2 instance type format."
  }
}

variable "name" {
  type        = string
  default     = "rocky9-fips"
  description = "Name tag for the EC2 instance and related resources"
}

variable "root_volume_size" {
  type        = number
  default     = 10
  description = "Root EBS volume size in GB"
}

variable "create_spot_instance" {
  type        = bool
  default     = false
  description = "Create an EC2 Spot Instance. Warning: spot instances can be interrupted by AWS."
}

variable "enable_termination_protection" {
  type        = bool
  default     = false
  description = "Enable EC2 termination protection to prevent accidental instance deletion"
}

variable "delete_volume_on_termination" {
  type        = bool
  default     = false
  description = "Delete EBS root volume when instance is terminated. Set to false to preserve data."
}

variable "user_data_extra" {
  type        = string
  default     = ""
  description = "Additional shell commands appended to the end of cloud-init runcmd"
}

#=============================================================================
# Network & Access
#=============================================================================

variable "ip_allow_ssh" {
  type        = set(string)
  default     = []
  description = "CIDR blocks allowed SSH access. Empty default requires explicit configuration."
  validation {
    condition = alltrue([
      for a in var.ip_allow_ssh : can(cidrnetmask(a))
    ])
    error_message = "All elements must be valid IPv4 CIDR block addresses."
  }
}

variable "enable_ssh" {
  type        = bool
  default     = true
  description = "Enable SSH access (port 22). Set to false for SSM-only access."
}

variable "enable_ssm" {
  type        = bool
  default     = false
  description = "Enable AWS Systems Manager Session Manager access"
}

variable "additional_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Additional security group IDs to attach to the instance"
}

#=============================================================================
# Monitoring & Logging
#=============================================================================

variable "enable_cloudwatch_logs" {
  type        = bool
  default     = false
  description = "Enable CloudWatch agent to ship logs and metrics"
}

variable "cloudwatch_log_retention_days" {
  type        = number
  default     = 365
  description = "CloudWatch Logs retention in days"
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

variable "cloudwatch_kms_key_id" {
  type        = string
  default     = null
  description = "KMS Key ARN for CloudWatch Logs encryption. If null, CloudWatch internal encryption is used."
}

variable "enable_security_alarms" {
  type        = bool
  default     = false
  description = "Enable CloudWatch alarms for security events (failed SSH, disk space, CPU)"
}

variable "create_sns_topic" {
  type        = bool
  default     = false
  description = "Create an SNS topic for alarm notifications. If false, use alarm_sns_topic_arn for existing topic."
}

variable "alarm_email" {
  type        = string
  default     = null
  description = "Email address for alarm notifications"
}

variable "alarm_sns_topic_arn" {
  type        = string
  default     = null
  description = "Existing SNS Topic ARN for CloudWatch alarm notifications"
}

#=============================================================================
# Data Protection
#=============================================================================

variable "enable_ebs_snapshots" {
  type        = bool
  default     = false
  description = "Enable automated daily EBS snapshots via AWS Data Lifecycle Manager"
}

variable "snapshot_retention_days" {
  type        = number
  default     = 7
  description = "Number of days to retain EBS snapshots"
  validation {
    condition     = var.snapshot_retention_days >= 1 && var.snapshot_retention_days <= 365
    error_message = "Snapshot retention must be between 1 and 365 days."
  }
}

variable "snapshot_time" {
  type        = string
  default     = "05:00"
  description = "Time of day (UTC) to take daily EBS snapshots (HH:MM format)"
  validation {
    condition     = can(regex("^([01]?[0-9]|2[0-3]):[0-5][0-9]$", var.snapshot_time))
    error_message = "Snapshot time must be in HH:MM format (e.g., 05:00)."
  }
}

#=============================================================================
# IAM
#=============================================================================

variable "aws_iam_policy_arns" {
  type        = list(string)
  default     = []
  description = "Additional managed IAM policy ARNs to attach to the instance role"
  validation {
    condition     = length(var.aws_iam_policy_arns) <= 10
    error_message = "Number of AWS IAM Policy ARNs should be 10 or less."
  }
}

#=============================================================================
# Tags
#=============================================================================

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to merge with module defaults"
}
