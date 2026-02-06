# Complete Example

Deploys a Rocky Linux 9 FIPS instance with all configurable features.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

## What This Creates

- EC2 instance with Rocky 9 FIPS AMI
- Security group with SSH access
- CloudWatch Logs + metrics dashboard (when enabled)
- Security alarms with SNS notifications (when enabled)
- Automated EBS snapshots via DLM (when enabled)
- IAM role with least-privilege policies

## Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_cloudwatch_logs` | `true` | CloudWatch agent + log shipping |
| `enable_security_alarms` | `false` | Failed SSH, disk, CPU alarms |
| `create_sns_topic` | `false` | SNS topic for alarm notifications |
| `enable_ebs_snapshots` | `false` | Daily DLM snapshots |
| `enable_ssm` | `false` | SSM Session Manager |
| `create_spot_instance` | `false` | Spot instance (can be interrupted) |
