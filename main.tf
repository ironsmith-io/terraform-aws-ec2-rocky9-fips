
# Rocky Linux 9 FIPS EC2 instance
resource "aws_instance" "this" {
  ami                         = local.ami_id
  key_name                    = var.key_pair_name
  instance_type               = var.instance_type
  vpc_security_group_ids      = concat([aws_security_group.this.id], var.additional_security_group_ids)
  subnet_id                   = var.subnet_id
  tags                        = local.common_tags
  iam_instance_profile        = local.use_instance_profile ? aws_iam_instance_profile.this[0].name : null
  disable_api_termination     = var.enable_termination_protection
  associate_public_ip_address = var.enable_public_ip

  user_data = templatefile("${path.module}/cloud-init.yml", {
    enable_cloudwatch_logs        = var.enable_cloudwatch_logs
    enable_ssm                    = var.enable_ssm
    enable_ssh                    = var.enable_ssh
    user_data_extra               = var.user_data_extra
    log_group_name                = local.log_group_name
    cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  })

  # Spot instance configuration (conditional)
  dynamic "instance_market_options" {
    for_each = var.create_spot_instance ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = var.ebs_volume_type
    volume_size           = var.root_volume_size
    iops                  = var.ebs_iops
    throughput            = var.ebs_throughput
    delete_on_termination = var.delete_volume_on_termination
    encrypted             = true
    tags                  = local.common_tags
  }

  # Prevent accidental instance replacement when user_data variables change
  # To force replacement: terraform taint module.rocky9_fips.aws_instance.this
  lifecycle {
    ignore_changes = [user_data]

    precondition {
      condition     = var.enable_ssh || var.enable_ssm
      error_message = "At least one of enable_ssh or enable_ssm must be true for remote access."
    }

    precondition {
      condition     = !var.enable_ssh || var.key_pair_name != null
      error_message = "key_pair_name is required when enable_ssh = true."
    }
  }
}

#=============================================================================
# Security Group
#=============================================================================

resource "aws_security_group" "this" {
  name        = "${var.name}-ec2"
  description = "Security group for Rocky 9 FIPS instance"
  vpc_id      = data.aws_subnet.selected.vpc_id
  tags        = local.common_tags

  # SSH access (conditional)
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "TCP"
      description = "Allow SSH access"
      cidr_blocks = var.ip_allow_ssh
    }
  }

  # Custom ingress rules
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "TCP"
      description = ingress.value.description
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow all outbound traffic"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
