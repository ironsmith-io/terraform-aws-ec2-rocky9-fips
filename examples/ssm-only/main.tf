# SSM-only Rocky 9 FIPS deployment
# No SSH, no key pair — access via AWS Systems Manager only
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

  # SSM-only access (no SSH)
  enable_ssh = false
  enable_ssm = true
}
