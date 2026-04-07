package test

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	awssqs "github.com/aws/aws-sdk-go-v2/service/sqs"
	sqstypes "github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestSQSModule deploys the sqs module, validates outputs and queue state,
// then destroys everything.
//
// Cost: essentially zero — idle SQS queues incur no standing monthly cost.
// Cleanup: defer terraform.Destroy runs even if assertions fail.
func TestSQSModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	queueName := resourceName(random.UniqueId())

	terraformOptions := terraformOptions(t, &terraform.Options{
		TerraformDir: "../modules/sqs",
		Vars: map[string]interface{}{
			"name":       queueName,
			"create_dlq": true,
			"tags":       testTags(),
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

	queueURL := terraform.Output(t, terraformOptions, "queue_id")
	queueARN := terraform.Output(t, terraformOptions, "queue_arn")
	queueOutputName := terraform.Output(t, terraformOptions, "queue_name")
	dlqURL := terraform.Output(t, terraformOptions, "dlq_id")
	dlqARN := terraform.Output(t, terraformOptions, "dlq_arn")

	assert.Equal(t, queueName, queueOutputName, "output 'queue_name' should equal the queue name")
	assert.True(t, strings.HasPrefix(queueARN, "arn:aws:sqs:"),
		"output 'queue_arn' should be a valid SQS ARN, got: %s", queueARN)
	assert.NotEmpty(t, dlqURL, "dlq_id should not be empty when create_dlq = true")
	assert.NotEmpty(t, dlqARN, "dlq_arn should not be empty when create_dlq = true")

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")
	sqsClient := awssqs.NewFromConfig(cfg)

	mainAttrs, err := sqsClient.GetQueueAttributes(ctx, &awssqs.GetQueueAttributesInput{
		QueueUrl:       &queueURL,
		AttributeNames: []sqstypes.QueueAttributeName{sqstypes.QueueAttributeNameAll},
	})
	require.NoError(t, err, "get main queue attributes")

	assert.Equal(t, queueARN, mainAttrs.Attributes[string(sqstypes.QueueAttributeNameQueueArn)], "main queue ARN should match output")
	assert.Equal(t, "true", mainAttrs.Attributes[string(sqstypes.QueueAttributeNameSqsManagedSseEnabled)], "main queue should use SQS-managed SSE by default")
	assert.Contains(t, mainAttrs.Attributes[string(sqstypes.QueueAttributeNameRedrivePolicy)], dlqARN, "redrive policy should target the DLQ")

	dlqAttrs, err := sqsClient.GetQueueAttributes(ctx, &awssqs.GetQueueAttributesInput{
		QueueUrl:       &dlqURL,
		AttributeNames: []sqstypes.QueueAttributeName{sqstypes.QueueAttributeNameAll},
	})
	require.NoError(t, err, "get DLQ attributes")

	assert.Equal(t, dlqARN, dlqAttrs.Attributes[string(sqstypes.QueueAttributeNameQueueArn)], "DLQ ARN should match output")
	assert.Equal(t, "true", dlqAttrs.Attributes[string(sqstypes.QueueAttributeNameSqsManagedSseEnabled)], "DLQ should use SQS-managed SSE by default")
}
