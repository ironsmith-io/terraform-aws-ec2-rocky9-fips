# Integration Tests

Terratest integration tests that deploy real AWS resources and verify FIPS mode, SELinux, agents, tags, and outputs.

## Prerequisites

- Go 1.21+
- AWS credentials configured
- [AWS Marketplace subscription](https://aws.amazon.com/marketplace/pp/prodview-qoc5oyrenam2k) accepted
- SSH key pair created via `make keygen`

## Running

```bash
make test-integration
```

The Makefile reads `subnet_id` from `terraform.tfvars` and passes it as `TEST_SUBNET_ID`. Key pair name, key path, and region all default to project conventions.

Run a single test:

```bash
cd test && TEST_SUBNET_ID=subnet-xxx go test -v -timeout 30m -run TestRocky9FIPSMinimal
```

## Test Configurations

| Test | Example | Features | Runtime Checks |
|---|---|---|---|
| `TestRocky9FIPSMinimal` | `examples/minimal` | SSH only | FIPS, SELinux, XFS, tags, IMDSv2 |
| `TestRocky9FIPS` | `examples/complete` | CloudWatch + SSM | All outputs, FIPS, agents, tags, IMDSv2 |
| `TestRocky9FIPSFullMonitoring` | `examples/complete` | All features | SNS, alarms, snapshots, agents, FIPS |

All tests run in parallel. Expect ~15 minutes and minimal EC2 costs.
