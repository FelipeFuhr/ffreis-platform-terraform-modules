package test

import (
	"context"
	"fmt"
	"path/filepath"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	awscloudtrail "github.com/aws/aws-sdk-go-v2/service/cloudtrail"
	awslogs "github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
	awssns "github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCloudTrailModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	trailName := resourceName(random.UniqueId())
	bucketName := fmt.Sprintf("%s-cloudtrail", resourceName(random.UniqueId()))
	fixtureDir := test_structure.CopyTerraformFolderToTemp(t, "..", filepath.Join("test", "fixtures", "cloudtrail"))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: fixtureDir,
		Vars: map[string]interface{}{
			"aws_region":  region,
			"trail_name":  trailName,
			"bucket_name": bucketName,
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

	outputName := terraform.Output(t, terraformOptions, "trail_name")
	outputARN := terraform.Output(t, terraformOptions, "trail_arn")

	assert.Equal(t, trailName, outputName, "output 'trail_name' should equal the trail name")
	assert.Equal(t, fmt.Sprintf("/cloudtrail/%s", trailName), terraform.Output(t, terraformOptions, "cloudwatch_log_group_name"), "fixture should expose the default log group name")

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")

	cloudTrailClient := awscloudtrail.NewFromConfig(cfg)
	trails, err := cloudTrailClient.DescribeTrails(ctx, &awscloudtrail.DescribeTrailsInput{
		TrailNameList: []string{outputName},
	})
	require.NoError(t, err, "describe CloudTrail trail")
	require.Len(t, trails.TrailList, 1, "expected a single CloudTrail trail")

	trail := trails.TrailList[0]
	assert.Equal(t, outputARN, aws.ToString(trail.TrailARN), "trail ARN should match output")
	assert.False(t, aws.ToBool(trail.IsMultiRegionTrail), "test trail should stay single-region to minimize cost")
	assert.Equal(t, fmt.Sprintf("%s-cloudtrail", trailName), aws.ToString(trail.SnsTopicName), "SNS topic name should follow module naming")

	logsClient := awslogs.NewFromConfig(cfg)
	logGroupName := fmt.Sprintf("/cloudtrail/%s", trailName)
	logGroups, err := logsClient.DescribeLogGroups(ctx, &awslogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: aws.String(logGroupName),
	})
	require.NoError(t, err, "describe CloudWatch log groups")

	foundLogGroup := false
	for _, logGroup := range logGroups.LogGroups {
		if aws.ToString(logGroup.LogGroupName) != logGroupName {
			continue
		}

		foundLogGroup = true
		assert.EqualValues(t, 365, aws.ToInt32(logGroup.RetentionInDays), "CloudTrail log group should retain logs for 365 days")
		assert.Empty(t, aws.ToString(logGroup.KmsKeyId), "default CloudTrail log group should use AWS-managed encryption")
	}
	assert.True(t, foundLogGroup, "expected CloudTrail log group %s to exist", logGroupName)

	snsClient := awssns.NewFromConfig(cfg)
	snsTopicARN := aws.ToString(trail.SnsTopicARN)
	attrs, err := snsClient.GetTopicAttributes(ctx, &awssns.GetTopicAttributesInput{TopicArn: &snsTopicARN})
	require.NoError(t, err, "get SNS topic attributes")
	assert.Equal(t, "alias/aws/sns", attrs.Attributes["KmsMasterKeyId"], "default CloudTrail SNS topic should use the AWS-managed SNS key")
}
