# Integration Tests

Terratest integration tests that deploy real AWS resources and verify FIPS mode.

## Prerequisites

- Go 1.21+
- AWS credentials configured
- [AWS Marketplace subscription](https://aws.amazon.com/marketplace/pp/prodview-qoc5oyrenam2k) accepted
- EC2 key pair imported to AWS
- Private key file accessible locally

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `TEST_SUBNET_ID` | Public subnet with internet gateway route | `subnet-04d87240cad41f758` |
| `TEST_KEY_PAIR` | EC2 key pair name (must exist in AWS) | `ironsmith-rocky9-fips` |
| `TEST_PRIVATE_KEY_PATH` | Path to matching private key file | `./ironsmith-rocky9-fips.pem` |

## Running

```bash
export TEST_SUBNET_ID=subnet-xxxxxxxxxxxxxxxxx
export TEST_KEY_PAIR=my-keypair
export TEST_PRIVATE_KEY_PATH=./my-keypair.pem
make test-integration
```

Tests deploy an EC2 instance, wait for cloud-init, verify FIPS mode via SSH, then destroy all resources. Expect ~10 minutes and minimal EC2 costs.
