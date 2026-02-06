# Complete Rocky 9 FIPS deployment - all features exposed
#
# For Terraform Registry usage:
#   source  = "ironsmith-io/ec2-rocky9-fips/aws"
#   version = "~> 1.0"

provider "aws" {
  region = var.aws_region
}

module "rocky9_fips" {
  source = "../../"

  # Required
  subnet_id     = var.subnet_id
  key_pair_name = var.key_pair_name

  # Instance
  instance_type        = var.instance_type
  create_spot_instance = var.create_spot_instance
  root_volume_size     = var.root_volume_size
  name                 = var.name

  # Network & Access
  ip_allow_ssh                  = var.ip_allow_ssh
  enable_ssh                    = var.enable_ssh
  enable_ssm                    = var.enable_ssm
  additional_security_group_ids = var.additional_security_group_ids

  # Monitoring
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  enable_security_alarms = var.enable_security_alarms
  create_sns_topic       = var.create_sns_topic
  alarm_email            = var.alarm_email

  # Data Protection
  enable_ebs_snapshots          = var.enable_ebs_snapshots
  enable_termination_protection = var.enable_termination_protection

  # Tags
  tags = var.tags
}
