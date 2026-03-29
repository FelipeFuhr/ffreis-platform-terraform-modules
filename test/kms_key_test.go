package test

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestKMSKeyModule deploys the kms-key module with default settings,
// validates outputs and live key state, then destroys everything.
//
// Cost: ~$0.001 — KMS keys are billed at $1/month; key is destroyed at test end.
// Cleanup: defer terraform.Destroy runs even if assertions fail.
func TestKMSKeyModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	alias := resourceName(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/kms-key",
		Vars: map[string]interface{}{
			"description": "Terratest ephemeral key — safe to delete",
			"alias":       alias,
			"tags":        testTags(),
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

	keyID     := terraform.Output(t, terraformOptions, "key_id")
	keyARN    := terraform.Output(t, terraformOptions, "key_arn")
	aliasARN  := terraform.Output(t, terraformOptions, "alias_arn")
	aliasName := terraform.Output(t, terraformOptions, "alias_name")

	assert.NotEmpty(t, keyID)
	assert.True(t, strings.HasPrefix(keyARN, "arn:aws:kms:"),
		"key_arn %q must start with arn:aws:kms:", keyARN)
	assert.NotEmpty(t, aliasARN)
	assert.Equal(t, "alias/"+alias, aliasName,
		"alias_name must be 'alias/<alias>'")

	// ── AWS SDK validation ───────────────────────────────────────────────────

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")
	kmsClient := kms.NewFromConfig(cfg)

	// 1. Key is in ENABLED state.
	descResp, err := kmsClient.DescribeKey(ctx, &kms.DescribeKeyInput{KeyId: &keyID})
	require.NoError(t, err, "describe key %s", keyID)
	require.NotNil(t, descResp.KeyMetadata)
	assert.Equal(t, "ENABLED", string(descResp.KeyMetadata.KeyState),
		"key must be in ENABLED state immediately after creation")

	// 2. Annual rotation is enabled by default (enable_key_rotation = true).
	rotResp, err := kmsClient.GetKeyRotationStatus(ctx, &kms.GetKeyRotationStatusInput{KeyId: &keyID})
	require.NoError(t, err, "get key rotation status for %s", keyID)
	assert.True(t, rotResp.KeyRotationEnabled,
		"annual key rotation must be on by default; set enable_key_rotation=false to opt out")

	// 3. The alias is registered for this key.
	aliasResp, err := kmsClient.ListAliases(ctx, &kms.ListAliasesInput{KeyId: &keyID})
	require.NoError(t, err, "list aliases for key %s", keyID)
	var aliasFound bool
	for _, a := range aliasResp.Aliases {
		if a.AliasName != nil && *a.AliasName == "alias/"+alias {
			aliasFound = true
			break
		}
	}
	assert.True(t, aliasFound,
		"alias %q must be registered for key %s", "alias/"+alias, keyID)
}
