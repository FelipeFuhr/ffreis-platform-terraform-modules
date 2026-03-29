module github.com/ffreis/platform-terraform-modules/test

go 1.21

require (
	github.com/aws/aws-sdk-go-v2/config v1.27.9
	github.com/aws/aws-sdk-go-v2/service/dynamodb v1.31.1
	github.com/aws/aws-sdk-go-v2/service/iam v1.31.3
	github.com/aws/aws-sdk-go-v2/service/kms v1.31.0
	github.com/aws/aws-sdk-go-v2/service/s3 v1.53.1
	github.com/gruntwork-io/terratest v0.46.16
	github.com/stretchr/testify v1.9.0
)

// Run `go mod tidy` after cloning to generate go.sum.
