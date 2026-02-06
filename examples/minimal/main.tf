# Minimal Rocky 9 FIPS deployment
# Uses all default settings - SSH access only
#
# For Terraform Registry usage:
#   source  = "ironsmith-io/ec2-rocky9-fips/aws"
#   version = "~> 1.0"

provider "aws" {
  region = var.aws_region
}

module "rocky9_fips" {
  source = "../../"

  # Required variables
  subnet_id     = var.subnet_id
  key_pair_name = var.key_pair_name
  ip_allow_ssh  = var.ip_allow_ssh
}
