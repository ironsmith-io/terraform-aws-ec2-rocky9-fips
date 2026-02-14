# Minimal Example

Deploys a Rocky Linux 9 FIPS instance with default settings — SSH access only, no agents, no monitoring.

## Usage

```hcl
module "rocky9_fips" {
  source  = "ironsmith-io/ec2-rocky9-fips/aws"
  version = "~> 1.0"

  subnet_id     = "subnet-xxxxxxxxx"
  key_pair_name = "my-keypair"
  ip_allow_ssh  = ["10.0.0.0/8"]
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
- Security group with SSH access
- No CloudWatch, no SSM, no snapshots

## Verify FIPS

```bash
ssh rocky@$(terraform output -raw public_ip)
cat /proc/sys/crypto/fips_enabled  # Should return 1
```
