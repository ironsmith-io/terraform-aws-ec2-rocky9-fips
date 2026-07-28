package test

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	terratest_aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// =============================================================================
// Helpers
// =============================================================================

// getTestEnv returns test configuration using project conventions from
// `make setup` and `make keygen`. Only TEST_SUBNET_ID is required
// (read from terraform.tfvars by the Makefile).
func getTestEnv(t *testing.T) (subnetID, keyPair, privateKeyPath, awsRegion string) {
	subnetID = os.Getenv("TEST_SUBNET_ID")
	require.NotEmpty(t, subnetID, "TEST_SUBNET_ID must be set")

	keyPair = "ironsmith-rocky9-fips"
	privateKeyPath = "../id_rsa_rocky9_fips"

	awsRegion = os.Getenv("TEST_AWS_REGION")
	if awsRegion == "" {
		awsRegion = "us-east-1"
	}
	return
}

// buildSSHHost creates an SSH host for the given instance.
func buildSSHHost(t *testing.T, publicIP, privateKeyPath string) ssh.Host {
	keyPairData, err := os.ReadFile(privateKeyPath)
	require.NoError(t, err)
	return ssh.Host{
		Hostname:    publicIP,
		SshUserName: "rocky",
		SshKeyPair:  &ssh.KeyPair{PrivateKey: string(keyPairData)},
	}
}

// waitForCloudInit retries SSH until cloud-init completes.
func waitForCloudInit(t *testing.T, host ssh.Host) {
	ctx := context.Background()
	retry.DoWithRetryContext(t, ctx, "Wait for SSH and cloud-init", 20, 15*time.Second, func() (string, error) {
		return ssh.CheckSSHCommandContextE(t, ctx, &host, "cloud-init status --wait")
	})
}

// runFIPSChecks verifies FIPS mode is correctly enabled.
func runFIPSChecks(t *testing.T, host ssh.Host) {
	ctx := context.Background()
	t.Run("fips_kernel_enabled", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "cat /proc/sys/crypto/fips_enabled")
		require.NoError(t, err)
		assert.Contains(t, result, "1", "FIPS mode should be enabled")
	})

	t.Run("crypto_policy_fips", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "update-crypto-policies --show")
		require.NoError(t, err)
		assert.Contains(t, result, "FIPS", "Crypto policy should be FIPS")
	})

	t.Run("fips_mode_setup_check", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "sudo fips-mode-setup --check")
		require.NoError(t, err)
		assert.Contains(t, result, "enabled", "fips-mode-setup should report enabled")
	})

	t.Run("md5_blocked", func(t *testing.T) {
		result, _ := ssh.CheckSSHCommandContextE(t, ctx, &host, "openssl md5 /dev/null 2>&1")
		blocked := strings.Contains(result, "unsupported") ||
			strings.Contains(result, "not supported") ||
			strings.Contains(result, "disabled") ||
			strings.Contains(result, "Error setting digest")
		assert.True(t, blocked, "MD5 should be blocked by FIPS, got: %s", result)
	})
}

// runRuntimeChecks verifies SELinux, filesystem, and SSH port.
func runRuntimeChecks(t *testing.T, host ssh.Host) {
	ctx := context.Background()
	t.Run("selinux_enforcing", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "getenforce")
		require.NoError(t, err)
		assert.Contains(t, result, "Enforcing", "SELinux should be in Enforcing mode")
	})

	t.Run("root_filesystem_xfs", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "mount | grep ' / '")
		require.NoError(t, err)
		assert.Contains(t, result, "xfs", "Root filesystem should be XFS")
	})

	t.Run("ssh_port_listening", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "sudo ss -tlnp | grep ':22 '")
		require.NoError(t, err)
		assert.Contains(t, result, ":22", "SSH should be listening on port 22")
	})
}

// =============================================================================
// Test: Minimal (SSH-only, no IAM, no agents)
// =============================================================================

// TestRocky9FIPSMinimal deploys a minimal SSH-only instance and verifies
// core FIPS functionality, SELinux, filesystem, and tags.
func TestRocky9FIPSMinimal(t *testing.T) {
	t.Parallel()

	ctx := context.Background()

	subnetID, keyPair, privateKeyPath, awsRegion := getTestEnv(t)
	projectDir, err := files.CopyTerraformFolderToTemp("..", "rocky9-minimal-")
	require.NoError(t, err)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(projectDir, "examples", "minimal"),
		Vars: map[string]interface{}{
			"subnet_id":     subnetID,
			"key_pair_name": keyPair,
			"ip_allow_ssh":  []string{"0.0.0.0/0"},
			"name":          "rocky9-fips-minimal",
			"aws_region":    awsRegion,
		},
	})

	defer terraform.DestroyContext(t, ctx, terraformOptions)
	terraform.InitAndApplyContext(t, ctx, terraformOptions)

	instanceID := terraform.OutputContext(t, ctx, terraformOptions, "instance_id")
	publicIP := terraform.OutputContext(t, ctx, terraformOptions, "public_ip")
	amiID := terraform.OutputContext(t, ctx, terraformOptions, "ami_id")
	amiName := terraform.OutputContext(t, ctx, terraformOptions, "ami_name")
	sshCommand := terraform.OutputContext(t, ctx, terraformOptions, "ssh_command")

	t.Run("outputs_populated", func(t *testing.T) {
		assert.NotEmpty(t, instanceID)
		assert.NotEmpty(t, publicIP)
		assert.NotEmpty(t, amiID)
		assert.NotEmpty(t, amiName)
		assert.Contains(t, sshCommand, "rocky@", "SSH command should contain rocky@ user")
	})

	t.Run("tags_correct", func(t *testing.T) {
		tags := terratest_aws.GetTagsForEc2InstanceContext(t, ctx, awsRegion, instanceID)
		assert.Equal(t, "rocky9-fips-minimal", tags["Name"])
		assert.Equal(t, "terraform", tags["ManagedBy"])
		assert.Equal(t, "terraform-aws-ec2-rocky9-fips", tags["Module"])
		assert.Equal(t, "Rocky Linux 9", tags["OS"])
		assert.Equal(t, "enabled", tags["FIPS"])
	})

	host := buildSSHHost(t, publicIP, privateKeyPath)
	waitForCloudInit(t, host)
	runFIPSChecks(t, host)
	runRuntimeChecks(t, host)

	t.Run("imdsv2_enforced", func(t *testing.T) {
		// IMDSv1 should be blocked (http_tokens = "required")
		result, _ := ssh.CheckSSHCommandContextE(t, ctx, &host, "curl -s -o /dev/null -w '%{http_code}' http://169.254.169.254/latest/meta-data/instance-id")
		assert.Equal(t, "401", strings.TrimSpace(result), "IMDSv1 should return 401 (Unauthorized)")
	})
}

// =============================================================================
// Test: CloudWatch + SSM (standard deployment)
// =============================================================================

// TestRocky9FIPS deploys with CloudWatch and SSM enabled and runs all verifications.
func TestRocky9FIPS(t *testing.T) {
	t.Parallel()

	ctx := context.Background()

	subnetID, keyPair, privateKeyPath, awsRegion := getTestEnv(t)
	projectDir, err := files.CopyTerraformFolderToTemp("..", "rocky9-standard-")
	require.NoError(t, err)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(projectDir, "examples", "complete"),
		Vars: map[string]interface{}{
			"subnet_id":              subnetID,
			"key_pair_name":          keyPair,
			"ip_allow_ssh":           []string{"0.0.0.0/0"},
			"name":                   "rocky9-fips-standard",
			"enable_cloudwatch_logs": true,
			"enable_ssm":             true,
			"aws_region":             awsRegion,
		},
	})

	defer terraform.DestroyContext(t, ctx, terraformOptions)
	terraform.InitAndApplyContext(t, ctx, terraformOptions)

	// Collect all outputs
	instanceID := terraform.OutputContext(t, ctx, terraformOptions, "instance_id")
	publicIP := terraform.OutputContext(t, ctx, terraformOptions, "public_ip")
	privateIP := terraform.OutputContext(t, ctx, terraformOptions, "private_ip")
	amiID := terraform.OutputContext(t, ctx, terraformOptions, "ami_id")
	amiName := terraform.OutputContext(t, ctx, terraformOptions, "ami_name")
	securityGroupID := terraform.OutputContext(t, ctx, terraformOptions, "security_group_id")
	iamRoleArn := terraform.OutputContext(t, ctx, terraformOptions, "iam_role_arn")
	cwLogGroupName := terraform.OutputContext(t, ctx, terraformOptions, "cloudwatch_log_group_name")
	cwDashboardURL := terraform.OutputContext(t, ctx, terraformOptions, "cloudwatch_dashboard_url")

	t.Run("all_outputs_populated", func(t *testing.T) {
		assert.NotEmpty(t, instanceID)
		assert.NotEmpty(t, publicIP)
		assert.NotEmpty(t, privateIP)
		assert.NotEmpty(t, amiID)
		assert.NotEmpty(t, amiName)
		assert.NotEmpty(t, securityGroupID)
		assert.NotEmpty(t, iamRoleArn)
		assert.NotEmpty(t, cwLogGroupName)
		assert.NotEmpty(t, cwDashboardURL)
	})

	t.Run("cloudwatch_log_group_name", func(t *testing.T) {
		assert.Equal(t, "/rocky9-fips-standard/ec2", cwLogGroupName)
	})

	t.Run("tags_correct", func(t *testing.T) {
		tags := terratest_aws.GetTagsForEc2InstanceContext(t, ctx, awsRegion, instanceID)
		assert.Equal(t, "rocky9-fips-standard", tags["Name"])
		assert.Equal(t, "terraform", tags["ManagedBy"])
		assert.Equal(t, "terraform-aws-ec2-rocky9-fips", tags["Module"])
		assert.Equal(t, "Rocky Linux 9", tags["OS"])
		assert.Equal(t, "enabled", tags["FIPS"])
	})

	host := buildSSHHost(t, publicIP, privateKeyPath)
	waitForCloudInit(t, host)
	runFIPSChecks(t, host)
	runRuntimeChecks(t, host)

	t.Run("cloudwatch_agent_running", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "sudo systemctl is-active amazon-cloudwatch-agent")
		require.NoError(t, err)
		assert.Contains(t, result, "active", "CloudWatch agent should be running")
	})

	t.Run("ssm_agent_running", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "sudo systemctl is-active amazon-ssm-agent")
		require.NoError(t, err)
		assert.Contains(t, result, "active", "SSM agent should be running")
	})

	t.Run("imdsv2_enforced", func(t *testing.T) {
		result, _ := ssh.CheckSSHCommandContextE(t, ctx, &host, "curl -s -o /dev/null -w '%{http_code}' http://169.254.169.254/latest/meta-data/instance-id")
		assert.Equal(t, "401", strings.TrimSpace(result), "IMDSv1 should return 401 (Unauthorized)")
	})
}

// =============================================================================
// Test: Full Monitoring (all features enabled)
// =============================================================================

// TestRocky9FIPSFullMonitoring deploys with all features enabled and verifies
// monitoring resources, alarms, SNS, and EBS snapshots are created.
func TestRocky9FIPSFullMonitoring(t *testing.T) {
	t.Parallel()

	ctx := context.Background()

	subnetID, keyPair, privateKeyPath, awsRegion := getTestEnv(t)
	projectDir, err := files.CopyTerraformFolderToTemp("..", "rocky9-full-")
	require.NoError(t, err)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(projectDir, "examples", "complete"),
		Vars: map[string]interface{}{
			"subnet_id":              subnetID,
			"key_pair_name":          keyPair,
			"ip_allow_ssh":           []string{"0.0.0.0/0"},
			"enable_cloudwatch_logs": true,
			"enable_ssm":             true,
			"enable_security_alarms": true,
			"create_sns_topic":       true,
			"alarm_email":            "test@example.com",
			"enable_ebs_snapshots":   true,
			"name":                   "rocky9-fips-full",
			"aws_region":             awsRegion,
		},
	})

	defer terraform.DestroyContext(t, ctx, terraformOptions)
	terraform.InitAndApplyContext(t, ctx, terraformOptions)

	instanceID := terraform.OutputContext(t, ctx, terraformOptions, "instance_id")
	publicIP := terraform.OutputContext(t, ctx, terraformOptions, "public_ip")
	snsTopicArn := terraform.OutputContext(t, ctx, terraformOptions, "sns_topic_arn")
	cwLogGroupName := terraform.OutputContext(t, ctx, terraformOptions, "cloudwatch_log_group_name")
	cwDashboardURL := terraform.OutputContext(t, ctx, terraformOptions, "cloudwatch_dashboard_url")
	iamRoleArn := terraform.OutputContext(t, ctx, terraformOptions, "iam_role_arn")

	t.Run("all_outputs_populated", func(t *testing.T) {
		assert.NotEmpty(t, instanceID)
		assert.NotEmpty(t, publicIP)
		assert.NotEmpty(t, snsTopicArn)
		assert.NotEmpty(t, cwLogGroupName)
		assert.NotEmpty(t, cwDashboardURL)
		assert.NotEmpty(t, iamRoleArn)
	})

	t.Run("sns_topic_created", func(t *testing.T) {
		assert.Contains(t, snsTopicArn, "arn:", "SNS topic ARN should be valid")
		assert.Contains(t, snsTopicArn, "rocky9-fips-full", "SNS topic should contain instance name")
	})

	t.Run("log_group_name", func(t *testing.T) {
		assert.Equal(t, "/rocky9-fips-full/ec2", cwLogGroupName)
	})

	t.Run("tags_correct", func(t *testing.T) {
		tags := terratest_aws.GetTagsForEc2InstanceContext(t, ctx, awsRegion, instanceID)
		assert.Equal(t, "rocky9-fips-full", tags["Name"])
		assert.Equal(t, "terraform", tags["ManagedBy"])
		assert.Equal(t, "enabled", tags["FIPS"])
	})

	host := buildSSHHost(t, publicIP, privateKeyPath)
	waitForCloudInit(t, host)
	runFIPSChecks(t, host)
	runRuntimeChecks(t, host)

	t.Run("cloudwatch_agent_running", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "sudo systemctl is-active amazon-cloudwatch-agent")
		require.NoError(t, err)
		assert.Contains(t, result, "active")
	})

	t.Run("ssm_agent_running", func(t *testing.T) {
		result, err := ssh.CheckSSHCommandContextE(t, ctx, &host, "sudo systemctl is-active amazon-ssm-agent")
		require.NoError(t, err)
		assert.Contains(t, result, "active")
	})
}

// =============================================================================
// Test: Spot Instance
// =============================================================================

// TestRocky9FIPSSpot deploys a spot instance and verifies spot lifecycle,
// outputs, tags, and FIPS checks.
func TestRocky9FIPSSpot(t *testing.T) {
	t.Parallel()

	ctx := context.Background()

	subnetID, keyPair, privateKeyPath, awsRegion := getTestEnv(t)
	projectDir, err := files.CopyTerraformFolderToTemp("..", "rocky9-spot-")
	require.NoError(t, err)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(projectDir, "examples", "complete"),
		Vars: map[string]interface{}{
			"subnet_id":            subnetID,
			"key_pair_name":        keyPair,
			"ip_allow_ssh":         []string{"0.0.0.0/0"},
			"name":                 "rocky9-fips-spot",
			"create_spot_instance": true,
			"aws_region":           awsRegion,
		},
	})

	defer terraform.DestroyContext(t, ctx, terraformOptions)
	terraform.InitAndApplyContext(t, ctx, terraformOptions)

	instanceID := terraform.OutputContext(t, ctx, terraformOptions, "instance_id")
	publicIP := terraform.OutputContext(t, ctx, terraformOptions, "public_ip")
	amiID := terraform.OutputContext(t, ctx, terraformOptions, "ami_id")

	t.Run("outputs_populated", func(t *testing.T) {
		assert.NotEmpty(t, instanceID)
		assert.NotEmpty(t, publicIP)
		assert.NotEmpty(t, amiID)
	})

	t.Run("instance_is_spot", func(t *testing.T) {
		ec2Client := terratest_aws.NewEc2ClientContext(t, ctx, awsRegion)
		input := &ec2.DescribeInstancesInput{
			InstanceIds: []string{instanceID},
		}
		result, err := ec2Client.DescribeInstances(ctx, input)
		require.NoError(t, err)
		require.Len(t, result.Reservations, 1)
		require.Len(t, result.Reservations[0].Instances, 1)

		instance := result.Reservations[0].Instances[0]
		assert.Equal(t, types.InstanceLifecycleTypeSpot, instance.InstanceLifecycle, "Instance should be a spot instance")
	})

	t.Run("tags_correct", func(t *testing.T) {
		tags := terratest_aws.GetTagsForEc2InstanceContext(t, ctx, awsRegion, instanceID)
		assert.Equal(t, "rocky9-fips-spot", tags["Name"])
		assert.Equal(t, "terraform", tags["ManagedBy"])
		assert.Equal(t, "enabled", tags["FIPS"])
	})

	host := buildSSHHost(t, publicIP, privateKeyPath)
	waitForCloudInit(t, host)
	runFIPSChecks(t, host)
}
