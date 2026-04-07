package test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ec2TrustPolicy is a minimal trust policy allowing EC2 to assume the role.
// Uses a fixed service principal — no account IDs or sensitive values.
const ec2TrustPolicy = `{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}`

// TestIAMRoleModule deploys the iam-role module with a minimal EC2 trust policy,
// validates outputs and role state, then destroys everything.
//
// Cost: zero — IAM roles have no per-resource cost.
// Cleanup: defer terraform.Destroy runs even if assertions fail.
func TestIAMRoleModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	roleName := resourceName(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/iam-role",
		Vars: map[string]interface{}{
			"name":                  roleName,
			"assume_role_policy":    ec2TrustPolicy,
			"force_detach_policies": true, // required: detach any auto-attached policies before destroy
			"description":           "Terratest ephemeral role — safe to delete",
			"tags":                  testTags(),
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
		RetryableTerraformErrors: map[string]string{
			".*TooManyRequestsException.*": "AWS rate-limiting; retrying",
			".*RequestError.*":             "transient network error; retrying",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// ── Output validation ────────────────────────────────────────────────────

	outputName := terraform.Output(t, terraformOptions, "name")
	outputARN := terraform.Output(t, terraformOptions, "arn")
	outputID := terraform.Output(t, terraformOptions, "id") // unique_id

	assert.Equal(t, roleName, outputName, "output 'name' should equal the role name")
	assert.True(t, strings.HasPrefix(outputARN, "arn:aws:iam::"),
		"output 'arn' should be a valid IAM ARN, got: %s", outputARN)
	assert.NotEmpty(t, outputID, "output 'id' (unique_id) should not be empty")

	// ── AWS SDK validation ───────────────────────────────────────────────────

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")
	iamClient := iam.NewFromConfig(cfg)

	roleOut, err := iamClient.GetRole(ctx, &iam.GetRoleInput{RoleName: &roleName})
	require.NoError(t, err, "get role %s", roleName)
	require.NotNil(t, roleOut.Role)

	role := roleOut.Role

	// 1. Role ARN matches the Terraform output.
	require.NotNil(t, role.Arn)
	assert.Equal(t, outputARN, *role.Arn, "role ARN should match Terraform output")

	// 2. Trust policy allows EC2 service.
	require.NotNil(t, role.AssumeRolePolicyDocument)
	// AWS URL-encodes the policy document when returning it via the API.
	policyJSON, err := url.QueryUnescape(*role.AssumeRolePolicyDocument)
	require.NoError(t, err, "URL-decode trust policy")

	var trustPolicy map[string]interface{}
	require.NoError(t, json.Unmarshal([]byte(policyJSON), &trustPolicy), "parse trust policy JSON")

	statements, ok := trustPolicy["Statement"].([]interface{})
	require.True(t, ok && len(statements) > 0, "trust policy should have at least one statement")

	stmt, ok := statements[0].(map[string]interface{})
	require.True(t, ok)

	principal, ok := stmt["Principal"].(map[string]interface{})
	require.True(t, ok, "principal should be a map")

	service := fmt.Sprintf("%v", principal["Service"])
	assert.Equal(t, "ec2.amazonaws.com", service,
		"trust policy should allow ec2.amazonaws.com to assume the role")

	// 3. Max session duration is the default (3600s = 1h).
	require.NotNil(t, role.MaxSessionDuration)
	assert.Equal(t, int32(3600), *role.MaxSessionDuration,
		"max session duration should be 3600 seconds")

	// 4. The role has the expected description.
	require.NotNil(t, role.Description)
	assert.Equal(t, "Terratest ephemeral role — safe to delete", *role.Description)
}
