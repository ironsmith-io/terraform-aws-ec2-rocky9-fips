#=============================================================================
# Validation Checks (Terraform 1.5+)
#=============================================================================

check "security_alarms_require_cloudwatch" {
  assert {
    condition     = !var.enable_security_alarms || var.enable_cloudwatch_logs
    error_message = "enable_security_alarms requires enable_cloudwatch_logs = true."
  }
}

check "sns_topic_requires_alarms" {
  assert {
    condition     = !var.create_sns_topic || var.enable_security_alarms
    error_message = "create_sns_topic is only useful with enable_security_alarms = true."
  }
}

check "alarm_email_requires_sns_topic" {
  assert {
    condition     = var.alarm_email == null || var.create_sns_topic || var.alarm_sns_topic_arn != null
    error_message = "alarm_email requires create_sns_topic = true or alarm_sns_topic_arn to be set."
  }
}

check "kms_key_requires_cloudwatch" {
  assert {
    condition     = var.cloudwatch_kms_key_id == null || var.enable_cloudwatch_logs
    error_message = "cloudwatch_kms_key_id is only used when enable_cloudwatch_logs = true."
  }
}

check "elastic_ip_without_public_ip" {
  assert {
    condition     = !var.associate_elastic_ip || var.enable_public_ip
    error_message = "associate_elastic_ip requires enable_public_ip = true to be useful."
  }
}

check "iops_required_for_io_volumes" {
  assert {
    condition     = !contains(["io1", "io2"], var.ebs_volume_type) || var.ebs_iops != null
    error_message = "ebs_iops is required when ebs_volume_type is io1 or io2."
  }
}

check "throughput_only_for_gp3" {
  assert {
    condition     = var.ebs_throughput == null || var.ebs_volume_type == "gp3"
    error_message = "ebs_throughput is only applicable to gp3 volume type."
  }
}

check "iops_not_for_gp2" {
  assert {
    condition     = var.ebs_iops == null || var.ebs_volume_type != "gp2"
    error_message = "ebs_iops cannot be set for gp2 volume type."
  }
}
