// Package test contains Terratest integration tests for platform-terraform-modules.
//
// Tests require real AWS credentials. Set AWS_TEST_ROLE_ARN to the IAM role
// Terratest should assume, or pre-configure AWS credentials in the environment.
// If credentials are absent, all tests skip gracefully.
//
// Run:
//
//	go test -v -timeout 30m ./...
//
// Run a single test:
//
//	go test -v -timeout 30m -run TestS3BucketModule ./...
package test

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
)

const (
	// testPrefix is prepended to every resource name created by tests.
	// Use it to identify and bulk-clean up leaked resources if a test crashes.
	testPrefix = "tftest"

	// defaultRegion is used when AWS_TEST_REGION is not set.
	defaultRegion = "us-east-1"
)

// testRegion returns the AWS region for tests.
// Override with AWS_TEST_REGION env var.
func testRegion() string {
	if r := os.Getenv("AWS_TEST_REGION"); r != "" {
		return r
	}
	return defaultRegion
}

// testTags returns standard tags applied to every resource created by tests.
// These tags allow cost attribution and emergency bulk cleanup via tag policies.
func testTags() map[string]interface{} {
	return map[string]interface{}{
		"ManagedBy":   "terratest",
		"Environment": "test",
		"Repository":  "platform-terraform-modules",
	}
}

// skipIfNoCredentials skips the test if no AWS credentials are configured.
// This allows the test suite to run in CI without AWS access (tests are skipped,
// not failed) and only execute when credentials are explicitly provided.
func skipIfNoCredentials(t *testing.T) {
	t.Helper()

	ctx := context.Background()
	_, err := config.LoadDefaultConfig(ctx, config.WithRegion(testRegion()))
	if err != nil {
		t.Skipf("skipping: AWS credentials not configured: %v", err)
	}

	// Require an explicit test role to prevent accidental use of production credentials.
	if os.Getenv("AWS_TEST_ROLE_ARN") == "" && os.Getenv("AWS_ACCESS_KEY_ID") == "" {
		t.Skip("skipping: set AWS_TEST_ROLE_ARN or AWS_ACCESS_KEY_ID to run integration tests")
	}
}

// resourceName generates a unique, prefixed resource name safe for use in
// AWS resource identifiers. Suffix is lowercased and trimmed to fit S3/IAM limits.
func resourceName(uniqueID string) string {
	// Limit to 40 chars to stay safely under all resource name limits.
	name := fmt.Sprintf("%s-%s", testPrefix, strings.ToLower(uniqueID))
	if len(name) > 40 {
		name = name[:40]
	}
	return name
}
