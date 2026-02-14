# Private subnet Rocky 9 FIPS deployment
# No public IP, SSM-only access — suitable for internal/regulated workloads
#
# For Terraform Registry usage:
#   source  = "ironsmith-io/ec2-rocky9-fips/aws"
#   version = "~> 1.0"

provider "aws" {
  region = var.aws_region
}

module "rocky9_fips" {
  source = "../../"

  name      = var.name
  subnet_id = var.subnet_id

  # Private subnet — no public IP
  enable_public_ip = false

  # SSM-only access (no SSH)
  enable_ssh = false
  enable_ssm = true

  # Monitoring
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
}
