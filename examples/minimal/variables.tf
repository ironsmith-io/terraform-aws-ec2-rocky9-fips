variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet ID"
}

variable "key_pair_name" {
  type        = string
  description = "EC2 key pair name"
}

variable "ip_allow_ssh" {
  type        = set(string)
  default     = []
  description = "CIDR blocks allowed SSH access"
}
