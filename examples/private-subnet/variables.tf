variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id" {
  type        = string
  description = "Private subnet ID (must have NAT gateway for SSM and package updates)"
}

variable "name" {
  type    = string
  default = "rocky9-fips-private"
}

variable "enable_cloudwatch_logs" {
  type    = bool
  default = true
}
