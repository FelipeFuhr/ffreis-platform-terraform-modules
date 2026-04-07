package test

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	awsecr "github.com/aws/aws-sdk-go-v2/service/ecr"
	ecrtypes "github.com/aws/aws-sdk-go-v2/service/ecr/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestECRModule deploys the ecr module, validates outputs and repository state,
// then destroys everything.
//
// Cost: essentially zero — an empty ECR repository has no standing monthly cost.
// Cleanup: defer terraform.Destroy runs even if assertions fail.
func TestECRModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	repositoryName := resourceName(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/ecr",
		Vars: map[string]interface{}{
			"name":                       repositoryName,
			"force_delete":               true,
			"untagged_image_expiry_days": 0,
			"keep_image_count":           0,
			"tags":                       testTags(),
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

	outputName := terraform.Output(t, terraformOptions, "repository_name")
	outputARN := terraform.Output(t, terraformOptions, "repository_arn")
	outputURL := terraform.Output(t, terraformOptions, "repository_url")

	assert.Equal(t, repositoryName, outputName, "output 'repository_name' should equal the repository name")
	assert.True(t, strings.HasPrefix(outputARN, "arn:aws:ecr:"),
		"output 'repository_arn' should be a valid ECR ARN, got: %s", outputARN)
	assert.Contains(t, outputURL, repositoryName, "repository URL should include the repository name")

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")
	ecrClient := awsecr.NewFromConfig(cfg)

	repos, err := ecrClient.DescribeRepositories(ctx, &awsecr.DescribeRepositoriesInput{
		RepositoryNames: []string{repositoryName},
	})
	require.NoError(t, err, "describe repository %s", repositoryName)
	require.Len(t, repos.Repositories, 1, "expected a single repository")

	repo := repos.Repositories[0]
	require.NotNil(t, repo.RepositoryArn)
	assert.Equal(t, outputARN, *repo.RepositoryArn, "repository ARN should match output")
	assert.Equal(t, ecrtypes.ImageTagMutabilityImmutable, repo.ImageTagMutability, "repository should enforce immutable tags")
	require.NotNil(t, repo.ImageScanningConfiguration)
	assert.True(t, repo.ImageScanningConfiguration.ScanOnPush, "scan on push should be enabled")
	require.NotNil(t, repo.EncryptionConfiguration)
	assert.Equal(t, ecrtypes.EncryptionTypeAes256, repo.EncryptionConfiguration.EncryptionType, "default encryption should be AES256")
}
