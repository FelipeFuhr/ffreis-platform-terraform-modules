package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestCloudFrontWebsiteModuleValidate(t *testing.T) {
	t.Parallel()

	fixtureDir := test_structure.CopyTerraformFolderToTemp(t, "..", filepath.Join("test", "fixtures", "cloudfront-website-validate"))
	terraformOptions := terraformOptions(t, &terraform.Options{
		TerraformDir: fixtureDir,
	})

	terraform.InitAndValidate(t, terraformOptions)
}
