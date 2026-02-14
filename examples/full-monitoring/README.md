# Full Monitoring Example

Deploys a Rocky Linux 9 FIPS instance with all observability and alerting features enabled — CloudWatch logs, dashboards, security alarms, SNS notifications, EBS snapshots, and termination protection.

## Usage

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  subnet_id     = "subnet-xxxxxxxxx"
  key_pair_name = "my-keypair"
  ip_allow_ssh  = ["10.0.0.0/8"]
  enable_ssm    = true

  # Full monitoring stack
  enable_cloudwatch_logs = true
  enable_security_alarms = true
  create_sns_topic       = true
  alarm_email            = "alerts@example.com"

  # Data protection
  enable_ebs_snapshots          = true
  enable_termination_protection = true
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

- EC2 instance with SSH + SSM access
- Security group with SSH ingress
- IAM role with CloudWatch + SSM policies
- CloudWatch log group and operations dashboard
- Security alarms: failed SSH, high CPU, high disk, status check
- SNS topic with email subscription
- Daily EBS snapshots via DLM (7-day retention)
- Termination protection enabled

## Alarms

| Alarm | Threshold | Condition |
|-------|-----------|-----------|
| Failed SSH | > 5 attempts in 5 min | CloudWatch log metric filter |
| CPU Usage | > 90% for 15 min | EC2 built-in metric |
| Disk Usage | > 85% | CWAgent custom metric |
| Status Check | Any failure for 10 min | EC2 built-in metric |

## After Deploy

1. **Confirm SNS email** — check your inbox and click the confirmation link
2. **View dashboard** — `terraform output cloudwatch_dashboard_url`
3. **Connect** — `ssh rocky@$(terraform output -raw public_ip)` or `aws ssm start-session --target $(terraform output -raw instance_id)`
