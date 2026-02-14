# terraform-aws-ec2-rocky9-fips

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/ironsmith-io/ec2-rocky9-fips/aws)
[![CI](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/actions/workflows/ci.yml/badge.svg)](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/ironsmith-io/terraform-aws-ec2-rocky9-fips)](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/blob/main/LICENSE)
[![FIPS 140-3](https://img.shields.io/badge/FIPS_140--3-enabled-green.svg)](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5113)

> **Status: Pending AWS Marketplace Approval** — The AMI required by this module is awaiting AWS Marketplace approval. This module is not usable until the AMI listing is publicly available. Do not attempt to use this module until this notice is removed.

Terraform module that launches an EC2 instance from the [ironsmith Rocky Linux 9 FIPS AMI](https://aws.amazon.com/marketplace/pp/prodview-qoc5oyrenam2k) on AWS Marketplace. FIPS 140-3 mode is pre-enabled at the kernel level -- no additional configuration required.

## Overview

- **Rocky Linux 9** with FIPS mode enabled system-wide
- **FIPS 140-3 mode enabled** at kernel and crypto-policy level ([CMVP #5113](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5113) validated on Rocky 9.2)
- **Free AWS Marketplace AMI** -- pay only for EC2 infrastructure
- **Auto-discovers** the latest FIPS AMI, or pin a specific version
- **Feature flags** for CloudWatch, SSM, snapshots, alarms -- all opt-in
- **Security-first defaults** -- IMDSv2 enforced, EBS encrypted, empty CIDR defaults
- **GovCloud compatible** -- partition-aware ARNs via `data.aws_partition.current` ([details](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/blob/main/SECURITY.md#govcloud-compatibility))

## Prerequisites

### AWS Marketplace Subscription (one-time)

This module uses the ironsmith Rocky Linux 9 FIPS AMI from AWS Marketplace. Before first use, you must accept the free subscription:

1. Visit the [AMI Marketplace listing](https://aws.amazon.com/marketplace/pp/prodview-qoc5oyrenam2k)
2. Click **Continue to Subscribe**
3. Click **Accept Terms**
4. Wait for subscription to become active (usually seconds)

This is free -- you only pay for EC2 infrastructure costs. The subscription only needs to be done once per AWS account.

> **Note:** If you skip this step, `terraform apply` will fail with an `OptInRequired` error.

## Architecture

![Architecture Diagram](https://raw.githubusercontent.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/main/docs/architecture.png)

*Dashed borders indicate opt-in features. Generate with `make diagram`.*

## Quick Start

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  subnet_id     = "subnet-xxxxxxxxx"
  key_pair_name = "my-keypair"
  ip_allow_ssh  = ["10.0.0.0/8"]
}
```

## Usage

### Full Example

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  # Required
  subnet_id     = "subnet-xxxxxxxxx"
  key_pair_name = "my-keypair"

  # Instance
  instance_type        = "t3.medium"
  name                 = "my-fips-server"
  create_spot_instance = false

  # Network
  ip_allow_ssh = ["10.0.0.0/8"]
  enable_ssh   = true
  enable_ssm   = true

  # Monitoring
  enable_cloudwatch_logs = true
  enable_security_alarms = true
  create_sns_topic       = true
  alarm_email            = "alerts@example.com"

  # Data Protection
  enable_ebs_snapshots = true

  tags = {
    env  = "production"
    team = "platform"
  }
}
```

### SSM-Only Access (No SSH)

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  subnet_id  = "subnet-xxxxxxxxx"
  enable_ssh = false
  enable_ssm = true
}
```

No `key_pair_name` needed when SSH is disabled.

### AMI Selection

By default, the module auto-discovers the latest ironsmith Rocky 9 FIPS AMI from AWS Marketplace. You can pin a specific version:

```hcl
module "rocky9_fips" {
  source = "ironsmith-io/ec2-rocky9-fips/aws"

  ami_id    = "ami-0123456789abcdef0"  # Pin specific AMI
  subnet_id = "subnet-xxxxxxxxx"
}
```

> **Important: AMI updates cause instance replacement.** When a new AMI is published, `terraform plan` will show a destroy/create diff because the AMI ID changes via `most_recent = true`. This **replaces the instance** (new instance ID, new IP, data on instance store is lost). EBS root volumes are preserved by default (`delete_volume_on_termination = false`). For production, pin the AMI with `ami_id` to control when updates are applied.

### Access Combinations

| enable_ssm | enable_ssh | Result |
|------------|------------|--------|
| `false` | `true` | SSH only (traditional) |
| `true` | `true` | Both SSH and SSM |
| `true` | `false` | SSM only (most secure, no port 22) |

## FIPS Verification

After launch, verify FIPS mode on the instance:

```bash
ssh rocky@<public_ip>

# Kernel FIPS flag (must be 1)
cat /proc/sys/crypto/fips_enabled

# System crypto policy (must be FIPS)
update-crypto-policies --show

# FIPS mode setup check
sudo fips-mode-setup --check

# Verify weak algorithms are blocked
openssl md5 /dev/null  # Should fail (MD5 blocked by FIPS)
```

The AMI also includes verification documentation at `/usr/share/doc/ironsmith/rocky9-fips/`.

## Data Protection

| Feature | Default | Description |
|---------|---------|-------------|
| EBS Encryption | Always on | gp3 volumes, always encrypted |
| Volume Preservation | `true` | EBS persists after instance termination |
| EBS Snapshots | Off | Daily DLM snapshots (opt-in) |
| user_data Changes | Ignored | Prevents accidental instance replacement |

**Spot Instances:** When `create_spot_instance = true`, instances use persistent spot with stop-on-interruption. Suitable for dev/test. Not recommended for production workloads.

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `OptInRequired` error | Subscribe to the AMI on [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-qoc5oyrenam2k) first (free, one-time) |
| AMI not found | Verify Marketplace subscription is active. Check region is supported |
| SSH timeout | Verify `ip_allow_ssh` includes your IP. Check security group in AWS console |
| FIPS not enabled | Verify AMI was built by `ami-builder-rocky9-fips`. Check `cat /proc/sys/crypto/fips_enabled` |
| CloudWatch no data | Verify `enable_cloudwatch_logs = true` and IAM role has CloudWatch permissions |
| Plan shows instance replacement | A new AMI was published. Pin with `ami_id` to control updates. See [AMI Selection](#ami-selection) |

### Debug Commands

```bash
# View cloud-init output
make cloud-init

# Verify FIPS remotely
make fips-verify

# Check service status
make status
```

### Log Locations

| Log | Path |
|-----|------|
| Cloud-init output | `/var/log/cloud-init-output.log` |
| Security audit | `/var/log/audit/audit.log` |
| SSH auth | `/var/log/secure` |
| FIPS documentation | `/usr/share/doc/ironsmith/rocky9-fips/` |

## Examples

- [Minimal](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/tree/main/examples/minimal) - SSH only, no agents, no monitoring
- [SSM-Only](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/tree/main/examples/ssm-only) - No SSH, no key pair, SSM access only
- [Private Subnet](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/tree/main/examples/private-subnet) - No public IP, SSM + CloudWatch
- [Full Monitoring](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/tree/main/examples/full-monitoring) - All alarms, SNS, snapshots, termination protection
- [Complete](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/tree/main/examples/complete) - All variables exposed for customization

## Cost Estimation

All costs are approximate monthly estimates for `us-east-1`. Actual costs vary by region and usage.

### Per-Component Costs

| Component | Condition | Approximate Monthly Cost |
|-----------|-----------|--------------------------|
| EC2 t3.medium (on-demand) | Always | ~$30 |
| EC2 t3.medium (spot) | `create_spot_instance = true` | ~$9-12 (60-70% savings) |
| EBS gp3 10 GB | Always | ~$0.80 |
| EBS io1 10 GB + 5000 IOPS | `ebs_volume_type = "io1"` | ~$33.25 |
| CloudWatch Logs (5 GB ingested) | `enable_cloudwatch_logs = true` | ~$2.50 |
| CloudWatch Dashboard | `enable_cloudwatch_logs = true` | ~$3.00 |
| EBS Snapshots (10 GB, 7 retained) | `enable_ebs_snapshots = true` | ~$0.35 |
| SNS Topic | `create_sns_topic = true` | Free (under free tier) |
| Elastic IP (attached) | `associate_elastic_ip = true` | Free (while attached) |
| Data Transfer (first 100 GB) | Always | ~$9.00 |

### Example Configurations

| Configuration | Features | Estimated Monthly Cost |
|---------------|----------|------------------------|
| Dev / Spot | Spot, SSH only, gp3 | ~$10 |
| Dev / On-demand | On-demand, SSH only, gp3 | ~$31 |
| Production Minimal | On-demand, SSH+SSM, CloudWatch | ~$33 |
| Production Full | On-demand, SSH+SSM, CloudWatch, alarms, snapshots | ~$37 |
| High-Performance | On-demand, io1 w/ 5000 IOPS, CloudWatch, alarms | ~$165 |

> Costs do not include data transfer beyond 100 GB or custom managed policies.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0, < 7.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_dashboard.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_metric_filter.failed_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_metric_alarm.cpu_usage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.disk_usage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.failed_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.status_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_dlm_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dlm_lifecycle_policy) | resource |
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.dlm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.dlm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_sns_topic.alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_ami.rocky9_fips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_security_group_ids"></a> [additional\_security\_group\_ids](#input\_additional\_security\_group\_ids) | Additional security group IDs to attach to the instance | `list(string)` | `[]` | no |
| <a name="input_alarm_email"></a> [alarm\_email](#input\_alarm\_email) | Email address for alarm notifications | `string` | `null` | no |
| <a name="input_alarm_sns_topic_arn"></a> [alarm\_sns\_topic\_arn](#input\_alarm\_sns\_topic\_arn) | Existing SNS Topic ARN for CloudWatch alarm notifications | `string` | `null` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | Specific AMI ID to use. If null, auto-discovers the latest ironsmith Rocky 9 FIPS AMI. | `string` | `null` | no |
| <a name="input_ami_owner"></a> [ami\_owner](#input\_ami\_owner) | AMI owner. Use 'aws-marketplace' for the public Marketplace AMI, or an account ID for private copies. | `string` | `"aws-marketplace"` | no |
| <a name="input_ami_product_code"></a> [ami\_product\_code](#input\_ami\_product\_code) | AWS Marketplace product code for the Ironsmith Rocky 9 FIPS AMI | `string` | `"5fbnogz030e3m2ddf2yvlqhho"` | no |
| <a name="input_associate_elastic_ip"></a> [associate\_elastic\_ip](#input\_associate\_elastic\_ip) | Create and associate an Elastic IP for a stable public IP across stop/start cycles. | `bool` | `false` | no |
| <a name="input_aws_iam_policy_arns"></a> [aws\_iam\_policy\_arns](#input\_aws\_iam\_policy\_arns) | Additional managed IAM policy ARNs to attach to the instance role | `list(string)` | `[]` | no |
| <a name="input_cloudwatch_kms_key_id"></a> [cloudwatch\_kms\_key\_id](#input\_cloudwatch\_kms\_key\_id) | KMS Key ARN for CloudWatch Logs encryption. If null, CloudWatch internal encryption is used. | `string` | `null` | no |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | CloudWatch Logs retention in days | `number` | `365` | no |
| <a name="input_create_sns_topic"></a> [create\_sns\_topic](#input\_create\_sns\_topic) | Create an SNS topic for alarm notifications. If false, use alarm\_sns\_topic\_arn for existing topic. | `bool` | `false` | no |
| <a name="input_create_spot_instance"></a> [create\_spot\_instance](#input\_create\_spot\_instance) | Create an EC2 Spot Instance. Warning: spot instances can be interrupted by AWS. | `bool` | `false` | no |
| <a name="input_delete_volume_on_termination"></a> [delete\_volume\_on\_termination](#input\_delete\_volume\_on\_termination) | Delete EBS root volume when instance is terminated. Set to false to preserve data. | `bool` | `false` | no |
| <a name="input_ebs_iops"></a> [ebs\_iops](#input\_ebs\_iops) | Provisioned IOPS for the root volume. Required for io1/io2, optional for gp3 (default 3000). | `number` | `null` | no |
| <a name="input_ebs_throughput"></a> [ebs\_throughput](#input\_ebs\_throughput) | Throughput in MiB/s for the root volume. Only applicable to gp3 (default 125). | `number` | `null` | no |
| <a name="input_ebs_volume_type"></a> [ebs\_volume\_type](#input\_ebs\_volume\_type) | EBS volume type for the root volume | `string` | `"gp3"` | no |
| <a name="input_enable_cloudwatch_logs"></a> [enable\_cloudwatch\_logs](#input\_enable\_cloudwatch\_logs) | Enable CloudWatch agent to ship logs and metrics | `bool` | `false` | no |
| <a name="input_enable_ebs_snapshots"></a> [enable\_ebs\_snapshots](#input\_enable\_ebs\_snapshots) | Enable automated daily EBS snapshots via AWS Data Lifecycle Manager | `bool` | `false` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Associate a public IP address with the instance. Set to false for private subnet deployments. | `bool` | `true` | no |
| <a name="input_enable_security_alarms"></a> [enable\_security\_alarms](#input\_enable\_security\_alarms) | Enable CloudWatch alarms for security events (failed SSH, disk space, CPU) | `bool` | `false` | no |
| <a name="input_enable_ssh"></a> [enable\_ssh](#input\_enable\_ssh) | Enable SSH access (port 22). Set to false for SSM-only access. | `bool` | `true` | no |
| <a name="input_enable_ssm"></a> [enable\_ssm](#input\_enable\_ssm) | Enable AWS Systems Manager Session Manager access | `bool` | `false` | no |
| <a name="input_enable_termination_protection"></a> [enable\_termination\_protection](#input\_enable\_termination\_protection) | Enable EC2 termination protection to prevent accidental instance deletion | `bool` | `false` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Additional security group ingress rules beyond SSH. | <pre>list(object({<br/>    port        = number<br/>    cidr_blocks = list(string)<br/>    description = string<br/>  }))</pre> | `[]` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type | `string` | `"t3.medium"` | no |
| <a name="input_ip_allow_ssh"></a> [ip\_allow\_ssh](#input\_ip\_allow\_ssh) | CIDR blocks allowed SSH access. Empty default requires explicit configuration. | `set(string)` | `[]` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | EC2 key pair name for SSH access. Required when enable\_ssh = true. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name tag for the EC2 instance and related resources | `string` | `"rocky9-fips"` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Root EBS volume size in GB | `number` | `10` | no |
| <a name="input_snapshot_retention_days"></a> [snapshot\_retention\_days](#input\_snapshot\_retention\_days) | Number of days to retain EBS snapshots | `number` | `7` | no |
| <a name="input_snapshot_time"></a> [snapshot\_time](#input\_snapshot\_time) | Time of day (UTC) to take daily EBS snapshots (HH:MM format) | `string` | `"05:00"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet to launch the EC2 instance into. VPC is derived automatically. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to merge with module defaults | `map(string)` | `{}` | no |
| <a name="input_user_data_extra"></a> [user\_data\_extra](#input\_user\_data\_extra) | Additional shell commands appended to the end of cloud-init runcmd | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | AMI ID used for the instance (useful when auto-discovered) |
| <a name="output_ami_name"></a> [ami\_name](#output\_ami\_name) | AMI name (from data source) |
| <a name="output_cloudwatch_dashboard_url"></a> [cloudwatch\_dashboard\_url](#output\_cloudwatch\_dashboard\_url) | CloudWatch Operations Dashboard URL (when CloudWatch is enabled) |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | CloudWatch Log Group name (when CloudWatch is enabled) |
| <a name="output_elastic_ip"></a> [elastic\_ip](#output\_elastic\_ip) | Elastic IP address (when associate\_elastic\_ip is true) |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | IAM role ARN (when instance profile is created) |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | EC2 instance ID |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP address |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP address (if assigned) |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | SNS Topic ARN for alarm notifications (when create\_sns\_topic is true) |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | SSH command to connect to the instance |
<!-- END_TF_DOCS -->
