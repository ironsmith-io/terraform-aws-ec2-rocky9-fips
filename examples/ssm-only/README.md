# SSM-Only Example

Deploys a Rocky Linux 9 FIPS instance with AWS Systems Manager access only — no SSH port exposed, no key pair required. This is the most secure remote access pattern.

## Usage

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  subnet_id  = "subnet-xxxxxxxxx"
  enable_ssh = false
  enable_ssm = true
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

- EC2 instance with Rocky 9 FIPS AMI (t3.medium)
- Security group with no inbound rules (egress only)
- IAM role with SSM managed policy
- SSM agent installed via cloud-init

## Connect

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```
