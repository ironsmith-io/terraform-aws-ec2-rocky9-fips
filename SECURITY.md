# Security Policy

## Reporting a Vulnerability

To report a security vulnerability, please email **security@ironsmith.io** with:

- Description of the vulnerability
- Steps to reproduce
- Impact assessment

We will acknowledge receipt within 48 hours and provide an initial assessment within 5 business days. Please do not open public issues for security vulnerabilities.

## FIPS 140-3 Compliance Scope

This module provisions EC2 instances from the [ironsmith Rocky Linux 9 FIPS AMI](https://aws.amazon.com/marketplace/pp/prodview-qoc5oyrenam2k), which has FIPS mode enabled at the kernel level.

### What is validated

The AMI's cryptographic module is validated under [CMVP Certificate #5113](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5113):

- **Module:** Red Hat Enterprise Linux 9 - OpenSSL FIPS Provider
- **Validated kernel:** Rocky Linux 9.2 (`5.14.0-284.30.1.el9_2`)
- **Algorithms:** AES, SHA-2/3, RSA, ECDSA, HMAC, DRBG, KDF (per certificate)

### What is NOT validated

- **Kernel versions beyond 9.2** — The AMI ships Rocky Linux 9.x (latest). The FIPS cryptographic module is functionally identical on later kernels, but the specific binary has not been separately validated under CMVP #5113. FIPS mode is enabled and the same crypto policies apply. Organizations requiring exact certificate-to-binary traceability should pin to the 9.2 AMI using the `ami_id` variable.
- **Application-layer crypto** — Software installed after provisioning (via `user_data_extra` or manually) must independently comply with FIPS requirements. The system-wide crypto policy (`FIPS`) restricts OpenSSL and NSS, but applications using their own crypto libraries are not covered.
- **AWS infrastructure** — EBS encryption, network encryption, and IAM are AWS's responsibility under the [AWS shared responsibility model](https://aws.amazon.com/compliance/shared-responsibility-model/).

## NIST 800-53 Control Mapping

This module addresses the following NIST 800-53 controls. This mapping is informational and does not constitute a compliance certification — organizations must validate controls within their own authorization boundary.

| Control | Title | Module Feature |
|---------|-------|----------------|
| SC-13 | Cryptographic Protection | FIPS 140-3 kernel mode (CMVP #5113), system-wide FIPS crypto policy |
| SC-28 | Protection of Information at Rest | EBS encryption always enabled (`encrypted = true`) |
| AC-17 | Remote Access | SSH and SSM access controls, `ip_allow_ssh` CIDR allowlist, conditional port 22 |
| AC-3 | Access Enforcement | IAM role with least-privilege policies, IMDSv2 enforced |
| AU-2 | Audit Events | CloudWatch log shipping (syslog, secure, audit logs) |
| AU-6 | Audit Review, Analysis, and Reporting | CloudWatch dashboard, security alarms, SNS notifications |
| CM-7 | Least Functionality | Conditional SSH, conditional agents, no unnecessary services |
| CP-9 | System Backup | Automated EBS snapshots via DLM |
| SI-2 | Flaw Remediation | Security patching on first boot via cloud-init (`dnf upgrade --security`) |
| SI-4 | System Monitoring | CloudWatch metrics (CPU, memory, disk), status check alarms |

## GovCloud Compatibility

This module supports AWS GovCloud (US) regions. ARN construction uses `data.aws_partition.current` throughout, which resolves to `aws-us-gov` in GovCloud and `aws-cn` in China regions.

**Tested partitions:**

| Partition | Regions | Status |
|-----------|---------|--------|
| `aws` | us-east-1, us-west-2 | Tested in integration tests |
| `aws-us-gov` | us-gov-west-1, us-gov-east-1 | Supported (partition-aware ARNs), not tested in CI |
| `aws-cn` | cn-north-1, cn-northwest-1 | Supported (partition-aware ARNs), not tested in CI |

> **Note:** The AWS Marketplace AMI subscription must be accepted in each partition separately. GovCloud accounts require a separate Marketplace subscription from commercial accounts.

## Module Hardening

The following security controls are enforced by this module and cannot be disabled:

| Control | Implementation | Override |
|---------|---------------|----------|
| EBS encryption | `encrypted = true` on root volume | Cannot be disabled |
| IMDSv2 enforcement | `http_tokens = "required"` | Cannot be disabled |
| Empty SSH allowlist | `ip_allow_ssh` defaults to `[]` | Must explicitly set CIDRs |
| Remote access validation | Precondition: at least one of SSH or SSM must be enabled | Hard error on plan |
| SSH key validation | Precondition: `key_pair_name` required when SSH enabled | Hard error on plan |

Additional security features (opt-in):

- SELinux enforcing mode (baked into AMI)
- CloudWatch security alarms (failed SSH, high CPU, disk usage, status check)
- SNS alarm notifications
- EBS snapshot backups via DLM
- Termination protection

## Shared Responsibility

| Responsibility | Owner |
|---------------|-------|
| AMI base image hardening, FIPS kernel configuration | ironsmith (AMI publisher) |
| Module defaults, validation, IAM scoping | This module |
| Network configuration (VPC, subnets, NACLs, routing) | User |
| SSH key management and rotation | User |
| Application security, patching cadence | User |
| AWS account security (IAM users, MFA, billing) | User |
| Infrastructure encryption (EBS, network, S3) | AWS |

## Dependency Security

- **Terraform AWS Provider** `>= 5.0, < 7.0` — pinned to major version range
- **Pre-commit hooks** include [gitleaks](https://github.com/gitleaks/gitleaks) for secret detection and [checkov](https://www.checkov.io/) for infrastructure security scanning
- **No external modules** — this module has zero module dependencies
