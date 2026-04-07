package test

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	awssns "github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestSNSModule deploys the sns module, validates outputs and live topic
// attributes, then destroys everything.
//
// Cost: essentially zero — idle SNS topics have no standing monthly cost.
// Cleanup: defer terraform.Destroy runs even if assertions fail.
func TestSNSModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	topicName := resourceName(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/sns",
		Vars: map[string]interface{}{
			"name":         topicName,
			"display_name": "Terratest topic",
			"tags":         testTags(),
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

	outputName := terraform.Output(t, terraformOptions, "name")
	outputARN := terraform.Output(t, terraformOptions, "arn")

	assert.Equal(t, topicName, outputName, "output 'name' should equal the topic name")
	assert.True(t, strings.HasPrefix(outputARN, "arn:aws:sns:"),
		"output 'arn' should be a valid SNS ARN, got: %s", outputARN)

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")
	snsClient := awssns.NewFromConfig(cfg)

	attrs, err := snsClient.GetTopicAttributes(ctx, &awssns.GetTopicAttributesInput{TopicArn: &outputARN})
	require.NoError(t, err, "get topic attributes")

	assert.Equal(t, topicName, attrs.Attributes["TopicName"], "topic name should match")
	assert.Equal(t, "Terratest topic", attrs.Attributes["DisplayName"], "display name should match")
	assert.Equal(t, "alias/aws/sns", attrs.Attributes["KmsMasterKeyId"], "default encryption should use AWS-managed SNS key")
	assert.Equal(t, "false", attrs.Attributes["FifoTopic"], "standard topic should not be FIFO")
}
