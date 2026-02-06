# Changelog

## v1.0.0

### Initial Release

- Rocky Linux 9 FIPS AMI auto-discovery (by name pattern + product-code)
- AMI pinning via `ami_id` variable
- EC2 instance with IMDSv2, encrypted EBS, gp3 volumes
- Spot instance support
- Security group with conditional SSH ingress
- Additional security group attachment
- Conditional IAM role/instance profile
- CloudWatch Logs agent + metrics dashboard
- Security alarms (failed SSH, disk, CPU, status checks)
- SNS topic with email subscription
- EBS snapshots via DLM
- Terraform validation checks for feature flag dependencies
- Unit tests (terraform test with mock provider)
- Terratest integration tests (FIPS verification)
- Pre-commit hooks (fmt, validate, docs, tflint, checkov, gitleaks)
- GitHub Actions CI pipeline
- Minimal and complete examples
