# Full monitoring Rocky 9 FIPS deployment
# All observability and alerting features enabled
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
  name = var.name

  # Access
  ip_allow_ssh = var.ip_allow_ssh
  enable_ssh   = true
  enable_ssm   = true

  # Full monitoring stack
  enable_cloudwatch_logs = true
  enable_security_alarms = true
  create_sns_topic       = true
  alarm_email            = var.alarm_email

  # Data protection
  enable_ebs_snapshots          = true
  enable_termination_protection = var.enable_termination_protection
}
