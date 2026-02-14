variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to launch the instance into"
}

variable "key_pair_name" {
  type        = string
  description = "EC2 key pair name for SSH access"
}

variable "name" {
  type    = string
  default = "rocky9-fips-monitored"
}

variable "ip_allow_ssh" {
  type    = set(string)
  default = []
}

variable "alarm_email" {
  type        = string
  default     = null
  description = "Email address for alarm notifications (must be confirmed in SNS)"
}

variable "enable_termination_protection" {
  type    = bool
  default = true
}
