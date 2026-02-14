# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/) and uses
[Conventional Commits](https://www.conventionalcommits.org/) for automated releases.

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
