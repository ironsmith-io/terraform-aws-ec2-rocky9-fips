# Private Subnet Example

Deploys a Rocky Linux 9 FIPS instance in a private subnet with no public IP. Access is via SSM only. This is the recommended pattern for regulated workloads (FedRAMP, CMMC, ITAR).

## Prerequisites

- A private subnet with a NAT gateway (required for SSM agent, CloudWatch agent, and package updates)
- VPC endpoints for SSM are recommended but not required if NAT is available

## Usage

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  subnet_id        = "subnet-xxxxxxxxx"  # Private subnet
  enable_public_ip = false
  enable_ssh       = false
  enable_ssm       = true

  enable_cloudwatch_logs = true
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

- EC2 instance with no public IP
- Security group with no inbound rules (egress only)
- IAM role with SSM + CloudWatch policies
- CloudWatch log group and dashboard

## Connect

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```
