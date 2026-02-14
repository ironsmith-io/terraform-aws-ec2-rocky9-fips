variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "subnet_id" {
  type = string
}

variable "key_pair_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "name" {
  type    = string
  default = "rocky9-fips"
}

variable "root_volume_size" {
  type    = number
  default = 10
}

variable "create_spot_instance" {
  type    = bool
  default = false
}

variable "ebs_volume_type" {
  type    = string
  default = "gp3"
}

variable "ebs_iops" {
  type    = number
  default = null
}

variable "ebs_throughput" {
  type    = number
  default = null
}

variable "enable_public_ip" {
  type    = bool
  default = true
}

variable "associate_elastic_ip" {
  type    = bool
  default = false
}

variable "ingress_rules" {
  type = list(object({
    port        = number
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "ip_allow_ssh" {
  type    = set(string)
  default = []
}

variable "enable_ssh" {
  type    = bool
  default = true
}

variable "enable_ssm" {
  type    = bool
  default = false
}

variable "additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "enable_cloudwatch_logs" {
  type    = bool
  default = false
}

variable "enable_security_alarms" {
  type    = bool
  default = false
}

variable "create_sns_topic" {
  type    = bool
  default = false
}

variable "alarm_email" {
  type    = string
  default = null
}

variable "enable_ebs_snapshots" {
  type    = bool
  default = false
}

variable "enable_termination_protection" {
  type    = bool
  default = false
}

variable "tags" {
  type = map(string)
  default = {
    env = "dev"
  }
}
