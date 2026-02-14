# Testing

All tests run via `make`. No additional tools required beyond the prerequisites.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.5 | Unit tests (`terraform test`) |
| Go | >= 1.21 | Integration tests (Terratest) |
| pre-commit | any | Linting, formatting, security scans |

Integration tests also require AWS credentials and a [Marketplace subscription](https://aws.amazon.com/marketplace/pp/prodview-qoc5oyrenam2k) (free).

## Quick Reference

```bash
make test                # Lint + unit tests (no AWS, ~30s)
make test-unit           # Unit tests only (~15s)
make test-integration    # All 3 integration tests in parallel (~15min, deploys AWS)
make test-all            # Everything
```

## Unit Tests (no AWS)

58 tests covering variable validation, preconditions, check blocks, and feature flag combinations.

```bash
make test-unit
```

| Category | Count | What they test |
|----------|-------|---------------|
| Variable validation (`rejects_*`) | 20 | Invalid inputs: subnet format, CIDR, instance type, retention, volume size, EBS IOPS/throughput, ingress rules |
| Preconditions (`rejects_*`) | 2 | Hard errors: no remote access, SSH without key pair |
| Check block warnings (`warns_*`) | 9 | Warnings: alarms without CW, SNS without alarms, email without SNS, KMS without CW, EIP without public IP, io needs IOPS, throughput not for io, IOPS not for gp2 |
| Valid inputs (`accepts_*`) | 9 | Boundary values, valid formats, pinned AMI, instance types |
| Feature flags (`accepts_*`) | 8 | SSM-only, CloudWatch, all features, spot, snapshots, custom name, public IP disabled, EIP |
| EBS configurations (`accepts_*`) | 4 | io1, io2, gp2, gp3 with custom IOPS/throughput |
| Ingress & patterns (`accepts_*`) | 6 | Custom ingress rules, SSM-only pattern, private subnet, full monitoring |

## Integration Tests (deploys AWS resources)

4 deployment configurations run in parallel. Each deploys an EC2 instance, verifies via SSH and AWS API, then destroys.

### Setup

The Makefile reads `subnet_id` from `terraform.tfvars`. Everything else uses project conventions.

```bash
make setup                # One-time: creates tfvars + SSH key
# Edit examples/complete/terraform.tfvars — set subnet_id
make test-integration     # Just works
```

### Defaults

| Value | Default | Override |
|-------|---------|---------|
| Key pair name | `ironsmith-rocky9-fips` | `TEST_KEY_PAIR` |
| Private key path | `../id_rsa_rocky9_fips` | `TEST_PRIVATE_KEY_PATH` |
| AWS region | `us-east-1` | `TEST_AWS_REGION` |
| Subnet ID | from `terraform.tfvars` | `TEST_SUBNET_ID` |

### Run All

```bash
make test-integration
```

### Run One

```bash
cd test && TEST_SUBNET_ID=subnet-xxx go test -v -timeout 30m -run TestRocky9FIPSMinimal
cd test && TEST_SUBNET_ID=subnet-xxx go test -v -timeout 30m -run TestRocky9FIPS$
cd test && TEST_SUBNET_ID=subnet-xxx go test -v -timeout 30m -run TestRocky9FIPSFullMonitoring
```

Note: `-run TestRocky9FIPS$` uses `$` anchor to match only `TestRocky9FIPS`, not the other two.

### Test Matrix

| Test | Example | Features | Runtime Checks |
|------|---------|----------|----------------|
| `TestRocky9FIPSMinimal` | `examples/minimal` | SSH only | FIPS, SELinux, XFS, tags, IMDSv2 |
| `TestRocky9FIPS` | `examples/complete` | CloudWatch + SSM | All outputs, FIPS, SELinux, XFS, tags, agents, IMDSv2 |
| `TestRocky9FIPSFullMonitoring` | `examples/complete` | All features | SNS, log group, alarms, snapshots, FIPS, SELinux, agents |
| `TestRocky9FIPSSpot` | `examples/complete` | Spot instance | Spot lifecycle via AWS API, FIPS, SELinux |

### What Each Test Verifies

**FIPS (all tests):** kernel flag = 1, crypto policy = FIPS, fips-mode-setup = enabled, MD5 blocked

**Runtime (all tests):** SELinux enforcing, root filesystem XFS, SSH port 22 listening

**Tags (all tests):** Name, ManagedBy, Module, OS, FIPS tags via AWS API

**Agents (standard + full):** CloudWatch agent active, SSM agent active

**Outputs (standard):** All 12 module outputs populated and correct

**Monitoring (full only):** SNS topic ARN valid, log group name matches `/{name}/ec2`

## Static Analysis

Included in `make test` via pre-commit:

```bash
make pre-commit         # Run all hooks
make validate           # terraform validate
make fmt-check          # terraform fmt check
make lint               # tflint
```

| Hook | What it checks |
|------|---------------|
| `terraform_fmt` | HCL formatting |
| `terraform_validate` | Configuration validity |
| `terraform_docs` | README auto-generation |
| `terraform_tflint` | Terraform linting |
| `terraform_checkov` | Security scanning (OWASP, CIS) |
| `golangci-lint` | Go test code linting |
| `gitleaks` | Secret detection |
