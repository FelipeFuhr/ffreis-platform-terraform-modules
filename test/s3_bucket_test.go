package test

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestS3BucketModule deploys the s3-bucket module, validates outputs and AWS
// resource state, then destroys everything.
//
// Cost: essentially zero — an empty S3 bucket with no requests incurs no charges.
// Cleanup: defer terraform.Destroy runs even if assertions fail.
func TestS3BucketModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	bucketName := resourceName(random.UniqueId())

	terraformOptions := terraformOptions(t, &terraform.Options{
		TerraformDir: "../modules/s3-bucket",
		Vars: map[string]interface{}{
			"bucket":             bucketName,
			"versioning_enabled": true,
			"force_destroy":      true, // required: allows Destroy even if objects exist
			"sse_algorithm":      "AES256",
			"tags":               testTags(),
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
		// Retry transient AWS API errors automatically.
		RetryableTerraformErrors: map[string]string{
			".*TooManyRequestsException.*": "AWS rate-limiting; retrying",
			".*RequestError.*":             "transient network error; retrying",
		},
	})

	// Destroy runs even if the test panics or any assertion fails.
	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// ── Output validation ────────────────────────────────────────────────────

	outputID := terraform.Output(t, terraformOptions, "id")
	outputARN := terraform.Output(t, terraformOptions, "arn")

	assert.Equal(t, bucketName, outputID, "output 'id' should equal the bucket name")
	assert.True(t, strings.HasPrefix(outputARN, "arn:aws:s3:::"),
		"output 'arn' should be a valid S3 ARN, got: %s", outputARN)

	// ── AWS SDK validation ───────────────────────────────────────────────────
	// These checks confirm the resource is in the expected state in AWS,
	// not just that Terraform reported the correct values.

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")
	s3Client := s3.NewFromConfig(cfg)

	// 1. Bucket exists.
	_, err = s3Client.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: &bucketName})
	require.NoError(t, err, "bucket %s should exist", bucketName)

	// 2. Versioning is enabled.
	versioning, err := s3Client.GetBucketVersioning(ctx, &s3.GetBucketVersioningInput{Bucket: &bucketName})
	require.NoError(t, err, "get bucket versioning")
	assert.Equal(t, types.BucketVersioningStatusEnabled, versioning.Status,
		"versioning should be Enabled")

	// 3. Public access block is fully enabled (all four settings = true).
	pab, err := s3Client.GetPublicAccessBlock(ctx, &s3.GetPublicAccessBlockInput{Bucket: &bucketName})
	require.NoError(t, err, "get public access block")
	require.NotNil(t, pab.PublicAccessBlockConfiguration)
	cfg2 := pab.PublicAccessBlockConfiguration
	assert.True(t, *cfg2.BlockPublicAcls, "BlockPublicAcls should be true")
	assert.True(t, *cfg2.BlockPublicPolicy, "BlockPublicPolicy should be true")
	assert.True(t, *cfg2.IgnorePublicAcls, "IgnorePublicAcls should be true")
	assert.True(t, *cfg2.RestrictPublicBuckets, "RestrictPublicBuckets should be true")

	// 4. Server-side encryption is configured.
	enc, err := s3Client.GetBucketEncryption(ctx, &s3.GetBucketEncryptionInput{Bucket: &bucketName})
	require.NoError(t, err, "get bucket encryption")
	require.NotEmpty(t, enc.ServerSideEncryptionConfiguration.Rules,
		"encryption rules should not be empty")
	algo := enc.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm
	assert.Equal(t, types.ServerSideEncryptionAes256, algo, "SSE algorithm should be AES256")
}
