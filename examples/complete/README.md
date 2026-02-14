# Complete Example

Deploys a Rocky Linux 9 FIPS instance with all configurable features.

## Usage

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  subnet_id     = "subnet-xxxxxxxxx"
  key_pair_name = "my-keypair"

  # Instance
  instance_type = "t3.medium"
  name          = "my-fips-server"

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
}
```

### Local Development

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
