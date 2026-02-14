# Unit Tests - terraform test
# Run with: terraform test -filter=tests/unit.tftest.hcl
# These tests validate variable validation rules and feature flag combinations (no AWS calls)

# =============================================================================
# Mock Provider - prevents AWS API calls during unit tests
# =============================================================================

mock_provider "aws" {
  mock_data "aws_subnet" {
    defaults = {
      id                      = "subnet-mock12345"
      vpc_id                  = "vpc-mock12345"
      availability_zone       = "us-west-2a"
      cidr_block              = "10.0.1.0/24"
      map_public_ip_on_launch = true
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id           = "ami-mock12345"
      name         = "ironsmith-rocky9-fips-9.7.20260205.0"
      architecture = "x86_64"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-west-2"
      id   = "us-west-2"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

# =============================================================================
# Negative Tests - Variable Validation
# =============================================================================

run "rejects_invalid_subnet_id" {
  command = plan

  variables {
    subnet_id     = "invalid"
    key_pair_name = "test-key"
  }

  expect_failures = [var.subnet_id]
}

run "rejects_subnet_id_wrong_prefix" {
  command = plan

  variables {
    subnet_id     = "vpc-12345678"
    key_pair_name = "test-key"
  }

  expect_failures = [var.subnet_id]
}

run "rejects_subnet_id_too_short" {
  command = plan

  variables {
    subnet_id     = "subnet-1234"
    key_pair_name = "test-key"
  }

  expect_failures = [var.subnet_id]
}

run "rejects_invalid_cidr_ssh" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    ip_allow_ssh  = ["not-a-cidr"]
  }

  expect_failures = [var.ip_allow_ssh]
}

run "rejects_partial_cidr" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    ip_allow_ssh  = ["192.168.1.1"]
  }

  expect_failures = [var.ip_allow_ssh]
}

run "rejects_invalid_instance_type" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    instance_type = "invalid-type"
  }

  expect_failures = [var.instance_type]
}

run "rejects_invalid_snapshot_time" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    snapshot_time = "25:00"
  }

  expect_failures = [var.snapshot_time]
}

run "rejects_snapshot_time_invalid_minutes" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    snapshot_time = "12:60"
  }

  expect_failures = [var.snapshot_time]
}

run "rejects_invalid_log_retention" {
  command = plan

  variables {
    subnet_id                     = "subnet-12345678"
    key_pair_name                 = "test-key"
    cloudwatch_log_retention_days = 999
  }

  expect_failures = [var.cloudwatch_log_retention_days]
}

run "rejects_too_many_iam_policies" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    aws_iam_policy_arns = [
      "arn:aws:iam::aws:policy/Policy1",
      "arn:aws:iam::aws:policy/Policy2",
      "arn:aws:iam::aws:policy/Policy3",
      "arn:aws:iam::aws:policy/Policy4",
      "arn:aws:iam::aws:policy/Policy5",
      "arn:aws:iam::aws:policy/Policy6",
      "arn:aws:iam::aws:policy/Policy7",
      "arn:aws:iam::aws:policy/Policy8",
      "arn:aws:iam::aws:policy/Policy9",
      "arn:aws:iam::aws:policy/Policy10",
      "arn:aws:iam::aws:policy/Policy11"
    ]
  }

  expect_failures = [var.aws_iam_policy_arns]
}

run "rejects_snapshot_retention_too_low" {
  command = plan

  variables {
    subnet_id               = "subnet-12345678"
    key_pair_name           = "test-key"
    snapshot_retention_days = 0
  }

  expect_failures = [var.snapshot_retention_days]
}

run "rejects_snapshot_retention_too_high" {
  command = plan

  variables {
    subnet_id               = "subnet-12345678"
    key_pair_name           = "test-key"
    snapshot_retention_days = 400
  }

  expect_failures = [var.snapshot_retention_days]
}

run "rejects_root_volume_too_small" {
  command = plan

  variables {
    subnet_id        = "subnet-12345678"
    key_pair_name    = "test-key"
    root_volume_size = 5
  }

  expect_failures = [var.root_volume_size]
}

# =============================================================================
# Negative Tests - Preconditions (hard errors on aws_instance)
# =============================================================================

run "rejects_no_remote_access" {
  command = plan

  variables {
    subnet_id  = "subnet-12345678"
    enable_ssh = false
    enable_ssm = false
  }

  expect_failures = [aws_instance.this]
}

run "rejects_ssh_without_keypair" {
  command = plan

  variables {
    subnet_id  = "subnet-12345678"
    enable_ssh = true
  }

  expect_failures = [aws_instance.this]
}

# =============================================================================
# Negative Tests - Check Block Warnings
# =============================================================================

run "warns_alarms_without_cloudwatch" {
  command = plan

  variables {
    subnet_id              = "subnet-12345678"
    key_pair_name          = "test-key"
    enable_security_alarms = true
    enable_cloudwatch_logs = false
  }

  expect_failures = [check.security_alarms_require_cloudwatch]
}

run "warns_sns_without_alarms" {
  command = plan

  variables {
    subnet_id              = "subnet-12345678"
    key_pair_name          = "test-key"
    create_sns_topic       = true
    enable_security_alarms = false
  }

  expect_failures = [check.sns_topic_requires_alarms]
}

run "warns_email_without_sns" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    alarm_email   = "test@example.com"
  }

  expect_failures = [check.alarm_email_requires_sns_topic]
}

run "warns_kms_without_cloudwatch" {
  command = plan

  variables {
    subnet_id             = "subnet-12345678"
    key_pair_name         = "test-key"
    cloudwatch_kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/mock-key-id"
  }

  expect_failures = [check.kms_key_requires_cloudwatch]
}

# =============================================================================
# Positive Tests - Valid Inputs
# =============================================================================

run "accepts_valid_minimal_config" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
  }
}

run "accepts_valid_17char_subnet_id" {
  command = plan

  variables {
    subnet_id     = "subnet-0123456789abcdef0"
    key_pair_name = "test-key"
  }
}

run "accepts_multiple_valid_cidrs" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    ip_allow_ssh  = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
}

run "accepts_empty_cidr_list" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    ip_allow_ssh  = []
  }
}

run "accepts_valid_snapshot_retention_boundary_low" {
  command = plan

  variables {
    subnet_id               = "subnet-12345678"
    key_pair_name           = "test-key"
    snapshot_retention_days = 1
  }
}

run "accepts_valid_snapshot_retention_boundary_high" {
  command = plan

  variables {
    subnet_id               = "subnet-12345678"
    key_pair_name           = "test-key"
    snapshot_retention_days = 365
  }
}

run "accepts_pinned_ami_id" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    ami_id        = "ami-0123456789abcdef0"
  }
}

run "accepts_valid_instance_types" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    instance_type = "c5.xlarge"
  }
}

run "accepts_metal_instance_type" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    instance_type = "c5.metal"
  }
}

# =============================================================================
# Feature Flag Tests - Conditional Resource Creation
# =============================================================================

run "accepts_ssm_only_no_keypair" {
  command = plan

  variables {
    subnet_id  = "subnet-12345678"
    enable_ssh = false
    enable_ssm = true
  }
}

run "accepts_cloudwatch_enabled" {
  command = plan

  variables {
    subnet_id              = "subnet-12345678"
    key_pair_name          = "test-key"
    enable_cloudwatch_logs = true
  }
}

run "accepts_all_features_enabled" {
  command = plan

  variables {
    subnet_id              = "subnet-12345678"
    key_pair_name          = "test-key"
    enable_ssh             = true
    enable_ssm             = true
    enable_cloudwatch_logs = true
    enable_security_alarms = true
    create_sns_topic       = true
    alarm_email            = "test@example.com"
    enable_ebs_snapshots   = true
  }
}

run "accepts_spot_instance" {
  command = plan

  variables {
    subnet_id            = "subnet-12345678"
    key_pair_name        = "test-key"
    create_spot_instance = true
  }
}

run "accepts_snapshots_with_custom_schedule" {
  command = plan

  variables {
    subnet_id               = "subnet-12345678"
    key_pair_name           = "test-key"
    enable_ebs_snapshots    = true
    snapshot_retention_days = 30
    snapshot_time           = "03:00"
  }
}

run "accepts_custom_name" {
  command = plan

  variables {
    subnet_id     = "subnet-12345678"
    key_pair_name = "test-key"
    name          = "my-custom-fips-server"
  }
}
