package test

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	ddbtypes "github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestDynamoDBTableModule deploys the dynamodb-table module with PAY_PER_REQUEST
// billing, validates outputs and table state, then destroys everything.
//
// Cost: zero — PAY_PER_REQUEST tables with no traffic cost nothing.
// Cleanup: defer terraform.Destroy runs even if assertions fail.
func TestDynamoDBTableModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	tableName := resourceName(random.UniqueId())

	terraformOptions := terraformOptions(t, &terraform.Options{
		TerraformDir: "../modules/dynamodb-table",
		Vars: map[string]interface{}{
			"name":         tableName,
			"hash_key":     "pk",
			"range_key":    "sk",
			"billing_mode": "PAY_PER_REQUEST", // zero cost with no traffic
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

	// ── Output validation ────────────────────────────────────────────────────

	outputID := terraform.Output(t, terraformOptions, "id")
	outputARN := terraform.Output(t, terraformOptions, "arn")

	assert.Equal(t, tableName, outputID, "output 'id' should equal the table name")
	assert.True(t, strings.Contains(outputARN, "dynamodb"),
		"output 'arn' should be a valid DynamoDB ARN, got: %s", outputARN)
	assert.True(t, strings.Contains(outputARN, region),
		"output 'arn' should contain the region %s, got: %s", region, outputARN)

	// ── AWS SDK validation ───────────────────────────────────────────────────

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")
	ddbClient := dynamodb.NewFromConfig(cfg)

	desc, err := ddbClient.DescribeTable(ctx, &dynamodb.DescribeTableInput{TableName: &tableName})
	require.NoError(t, err, "describe table %s", tableName)
	require.NotNil(t, desc.Table)

	table := desc.Table

	// 1. Table is ACTIVE.
	assert.Equal(t, ddbtypes.TableStatusActive, table.TableStatus,
		"table status should be ACTIVE")

	// 2. Billing mode is PAY_PER_REQUEST (no provisioned capacity).
	require.NotNil(t, table.BillingModeSummary)
	assert.Equal(t, ddbtypes.BillingModePayPerRequest, table.BillingModeSummary.BillingMode,
		"billing mode should be PAY_PER_REQUEST")

	// 3. Hash key and range key are correct.
	keySchema := table.KeySchema
	var hashKey, rangeKey string
	for _, k := range keySchema {
		switch k.KeyType {
		case ddbtypes.KeyTypeHash:
			hashKey = *k.AttributeName
		case ddbtypes.KeyTypeRange:
			rangeKey = *k.AttributeName
		}
	}
	assert.Equal(t, "pk", hashKey, "hash key should be 'pk'")
	assert.Equal(t, "sk", rangeKey, "range key should be 'sk'")

	// 4. Point-in-time recovery is enabled.
	pitr, err := ddbClient.DescribeContinuousBackups(ctx, &dynamodb.DescribeContinuousBackupsInput{
		TableName: &tableName,
	})
	require.NoError(t, err, "describe continuous backups")
	require.NotNil(t, pitr.ContinuousBackupsDescription)
	require.NotNil(t, pitr.ContinuousBackupsDescription.PointInTimeRecoveryDescription)
	assert.Equal(t,
		ddbtypes.PointInTimeRecoveryStatusEnabled,
		pitr.ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus,
		"point-in-time recovery should be ENABLED",
	)

	// 5. Server-side encryption is enabled.
	require.NotNil(t, table.SSEDescription)
	assert.Equal(t, ddbtypes.SSEStatusEnabled, table.SSEDescription.Status,
		"SSE should be ENABLED")
}
