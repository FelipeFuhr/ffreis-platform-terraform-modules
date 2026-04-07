package test

import (
	"context"
	"fmt"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	awslogs "github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
	awsecs "github.com/aws/aws-sdk-go-v2/service/ecs"
	ecstypes "github.com/aws/aws-sdk-go-v2/service/ecs/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestECSClusterModule(t *testing.T) {
	t.Parallel()
	skipIfNoCredentials(t)

	region := testRegion()
	clusterName := resourceName(random.UniqueId())
	expectedLogGroupName := fmt.Sprintf("/ecs/exec/%s", clusterName)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/ecs-cluster",
		Vars: map[string]interface{}{
			"name": clusterName,
			"tags": testTags(),
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

	assert.Equal(t, clusterName, outputName, "output 'name' should equal the cluster name")
	assert.Contains(t, outputARN, clusterName, "output 'arn' should contain the cluster name")

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")

	ecsClient := awsecs.NewFromConfig(cfg)
	clusters, err := ecsClient.DescribeClusters(ctx, &awsecs.DescribeClustersInput{
		Clusters: []string{outputARN},
		Include:  []ecstypes.ClusterField{ecstypes.ClusterFieldConfigurations, ecstypes.ClusterFieldSettings},
	})
	require.NoError(t, err, "describe ECS cluster")
	require.Len(t, clusters.Clusters, 1, "expected a single ECS cluster")

	cluster := clusters.Clusters[0]
	assert.Equal(t, clusterName, aws.ToString(cluster.ClusterName), "cluster name should match output")
	assert.ElementsMatch(t, []string{"FARGATE", "FARGATE_SPOT"}, cluster.CapacityProviders, "default capacity providers should use on-demand + spot")

	var containerInsights string
	for _, setting := range cluster.Settings {
		if string(setting.Name) == "containerInsights" {
			containerInsights = aws.ToString(setting.Value)
		}
	}
	assert.Equal(t, "enabled", containerInsights, "container insights should be enabled by default")

	require.NotNil(t, cluster.Configuration, "cluster configuration should exist")
	require.NotNil(t, cluster.Configuration.ExecuteCommandConfiguration, "execute command configuration should exist")
	execConfig := cluster.Configuration.ExecuteCommandConfiguration
	assert.Equal(t, ecstypes.ExecuteCommandLoggingOverride, execConfig.Logging, "execute command logging should be overridden to managed destinations")
	assert.Empty(t, aws.ToString(execConfig.KmsKeyId), "default exec configuration should not require a customer-managed KMS key")
	require.NotNil(t, execConfig.LogConfiguration, "execute command log configuration should exist")
	assert.Equal(t, expectedLogGroupName, aws.ToString(execConfig.LogConfiguration.CloudWatchLogGroupName), "exec logs should go to the managed CloudWatch log group")

	logsClient := awslogs.NewFromConfig(cfg)
	logGroups, err := logsClient.DescribeLogGroups(ctx, &awslogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: aws.String(expectedLogGroupName),
	})
	require.NoError(t, err, "describe CloudWatch log groups")

	foundLogGroup := false
	for _, logGroup := range logGroups.LogGroups {
		if aws.ToString(logGroup.LogGroupName) != expectedLogGroupName {
			continue
		}

		foundLogGroup = true
		assert.EqualValues(t, 365, aws.ToInt32(logGroup.RetentionInDays), "exec log group should retain logs for 365 days")
		assert.Empty(t, aws.ToString(logGroup.KmsKeyId), "default exec log group should use AWS-managed encryption")
	}
	assert.True(t, foundLogGroup, "expected exec log group %s to exist", expectedLogGroupName)
}
