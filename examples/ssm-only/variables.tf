variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to launch the instance into"
}

variable "name" {
  type    = string
  default = "rocky9-fips-ssm"
}
