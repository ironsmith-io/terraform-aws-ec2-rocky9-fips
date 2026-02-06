package test

import (
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestRocky9FIPS deploys once and runs all verifications as subtests.
// This avoids duplicate AWS deployments and saves time/cost.
func TestRocky9FIPS(t *testing.T) {
	t.Parallel()

	subnetID := os.Getenv("TEST_SUBNET_ID")
	keyPair := os.Getenv("TEST_KEY_PAIR")
	privateKeyPath := os.Getenv("TEST_PRIVATE_KEY_PATH")
	require.NotEmpty(t, subnetID, "TEST_SUBNET_ID must be set")
	require.NotEmpty(t, keyPair, "TEST_KEY_PAIR must be set")
	require.NotEmpty(t, privateKeyPath, "TEST_PRIVATE_KEY_PATH must be set")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/complete",
		Vars: map[string]interface{}{
			"subnet_id":            subnetID,
			"key_pair_name":        keyPair,
			"ip_allow_ssh":         []string{"0.0.0.0/0"},
			"enable_cloudwatch_logs": true,
			"enable_ssm":            true,
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Collect outputs
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	publicIP := terraform.Output(t, terraformOptions, "public_ip")
	amiID := terraform.Output(t, terraformOptions, "ami_id")

	t.Run("outputs_populated", func(t *testing.T) {
		assert.NotEmpty(t, instanceID)
		assert.NotEmpty(t, publicIP)
		assert.NotEmpty(t, amiID)
	})

	// Build SSH host
	keyPairData, err := os.ReadFile(privateKeyPath)
	require.NoError(t, err)

	host := ssh.Host{
		Hostname:    publicIP,
		SshUserName: "rocky",
		SshKeyPair:  &ssh.KeyPair{PrivateKey: string(keyPairData)},
	}

	// Wait for SSH and cloud-init to complete (retry instead of sleep)
	retry.DoWithRetry(t, "Wait for SSH", 20, 15*time.Second, func() (string, error) {
		return ssh.CheckSshCommandE(t, host, "cloud-init status --wait")
	})

	t.Run("fips_kernel_enabled", func(t *testing.T) {
		result, err := ssh.CheckSshCommandE(t, host, "cat /proc/sys/crypto/fips_enabled")
		require.NoError(t, err)
		assert.Contains(t, result, "1", "FIPS mode should be enabled")
	})

	t.Run("crypto_policy_fips", func(t *testing.T) {
		result, err := ssh.CheckSshCommandE(t, host, "update-crypto-policies --show")
		require.NoError(t, err)
		assert.Contains(t, result, "FIPS", "Crypto policy should be FIPS")
	})

	t.Run("fips_mode_setup_check", func(t *testing.T) {
		result, err := ssh.CheckSshCommandE(t, host, "sudo fips-mode-setup --check")
		require.NoError(t, err)
		assert.Contains(t, result, "enabled", "fips-mode-setup should report enabled")
	})

	t.Run("md5_blocked", func(t *testing.T) {
		result, _ := ssh.CheckSshCommandE(t, host, "openssl md5 /dev/null 2>&1")
		blocked := strings.Contains(result, "unsupported") ||
			strings.Contains(result, "not supported") ||
			strings.Contains(result, "disabled") ||
			strings.Contains(result, "Error setting digest")
		assert.True(t, blocked, "MD5 should be blocked by FIPS, got: %s", result)
	})

	t.Run("cloudwatch_agent_running", func(t *testing.T) {
		result, err := ssh.CheckSshCommandE(t, host, "sudo systemctl is-active amazon-cloudwatch-agent")
		require.NoError(t, err)
		assert.Contains(t, result, "active", "CloudWatch agent should be running")
	})

	t.Run("ssm_agent_running", func(t *testing.T) {
		result, err := ssh.CheckSshCommandE(t, host, "sudo systemctl is-active amazon-ssm-agent")
		require.NoError(t, err)
		assert.Contains(t, result, "active", "SSM agent should be running")
	})
}
