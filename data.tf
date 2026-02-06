# Look up VPC from subnet
data "aws_subnet" "selected" {
  id = var.subnet_id
}

# Current AWS region and partition
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Auto-discover latest ironsmith Rocky 9 FIPS AMI
data "aws_ami" "rocky9_fips" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = ["ironsmith-rocky9-fips-*"]
  }

  filter {
    name   = "product-code"
    values = [var.ami_product_code]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
