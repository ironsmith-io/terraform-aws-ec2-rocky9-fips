# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/) and uses
[Conventional Commits](https://www.conventionalcommits.org/) for automated releases.

## [v1.1.0](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/compare/v1.0.1...v1.1.0) (2026-02-14)

### Features

- 6 new variables: `enable_public_ip`, `associate_elastic_ip`, `ingress_rules`, `ebs_volume_type`, `ebs_iops`, `ebs_throughput`
- Elastic IP support with conditional `aws_eip` and `aws_eip_association`
- Dynamic security group ingress rules
- Parameterized root EBS volume (volume type, IOPS, throughput)
- 3 new deployment examples: `ssm-only`, `private-subnet`, `full-monitoring`
- NIST 800-53 control mapping and GovCloud compatibility in SECURITY.md
- Makefile `EXAMPLE=` parameter to target any example directory

### Bug Fixes

- Null-safe variable validations for Terraform 1.7.x compatibility (`ebs_iops`, `ebs_throughput`)

### Refactoring

- Split 621-line main.tf into 7 domain-specific files (`eip.tf`, `iam.tf`, `monitoring.tf`, `alarms.tf`, `dlm.tf`, `checks.tf`)
- Enhanced `.tflint.hcl` with `terraform_unused_declarations`, `terraform_deprecated_index`, and AWS plugin

### Tests

- 4 new check block warning tests (EIP, io IOPS, throughput, gp2 IOPS) — 58 unit tests total
- Spot instance integration test using AWS SDK `DescribeInstances`

### Documentation

- Example READMEs with Terraform Registry source blocks
- Cost estimation section in README

## [v1.0.1](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/compare/v1.0.0...v1.0.1) (2026-02-08)

### Bug Fixes

- Fix cloud-init log retention to use `cloudwatch_log_retention_days` variable instead of hardcoded 365

### Refactoring

- Convert `remote_access_required` and `ssh_requires_key_pair` from check blocks to preconditions (hard errors)

### Tests

- Add 6 negative tests for check block warnings
- Add SELinux, SSH port, XFS filesystem, tag, and IMDSv2 verification to Terratest
- Expand Terratest to 3 deployment configurations (minimal, standard, full monitoring)

### Documentation

- Add SECURITY.md with FIPS compliance scope and shared responsibility matrix
- Add TESTING.md with test matrix and execution guide
- Document AMI replacement behavior in README

## [v1.0.0](https://github.com/ironsmith-io/terraform-aws-ec2-rocky9-fips/releases/tag/v1.0.0) (2026-02-06)

### Features

- Rocky Linux 9 FIPS AMI auto-discovery (by name pattern + product-code)
- AMI pinning via `ami_id` variable
- EC2 instance with IMDSv2 enforced, encrypted EBS, gp3 volumes
- Spot instance support via `create_spot_instance`
- Security group with conditional SSH ingress
- Additional security group attachment
- Conditional IAM role/instance profile (CloudWatch, SSM, custom policies)
- CloudWatch Logs agent + metrics dashboard
- Security alarms (failed SSH, disk, CPU, status checks)
- SNS topic with email subscription for alarm notifications
- Automated EBS snapshots via DLM
- Terraform validation checks for feature flag dependencies
- Cloud-init bootstrap with conditional agent installation

### Tests

- Unit tests via `terraform test` with mock AWS provider
- Terratest integration tests with FIPS verification

### Documentation

- README with quick start, examples, access matrix, FIPS verification, troubleshooting
- Minimal and complete examples
- Pre-commit hooks (fmt, validate, docs, tflint, checkov, gitleaks)
- GitHub Actions CI pipeline
