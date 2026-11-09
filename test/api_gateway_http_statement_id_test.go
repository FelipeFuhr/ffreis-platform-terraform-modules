package test

import (
	"encoding/json"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// statementIDCharset is AWS's accepted set for aws_lambda_permission's
// statement_id. The provider enforces it with a schema validator, which means
// a violation surfaces at PLAN time — so this test needs no credentials, no
// network and no apply, and costs nothing. (It is not a *harmless* plan-time
// error: the module is consumed by every API in the fleet, and the plan it
// breaks is the whole stack's, not just the offending route's.)
var statementIDCharset = regexp.MustCompile(`^[a-zA-Z0-9_-]+$`)

// statementIDMaxLen is AWS's documented limit. Route keys are long and the
// prefix eats 22 characters, so this is worth asserting rather than assuming:
// the sanitizer maps characters one-to-one and never shortens.
const statementIDMaxLen = 100

// noChurnExpectations pins the statement_id for route-key shapes that already
// exist across the fleet. These are byte-exact on purpose.
//
// statement_id forces resource replacement. The tempting "tidy" fix for the
// dotted-key bug is to drop the four literal replaces for a single regex pass
// — but that collapses runs, turning "GET--api-issue" into "GET-api-issue",
// changing EVERY existing statement_id and so destroying and recreating every
// lambda permission in the fleet (a window where API Gateway cannot invoke the
// function) to fix a bug in none of them. The fix is therefore a fifth pass
// that is a no-op on these. If a refactor ever changes one of these strings,
// that is a fleet-wide migration and this test should fail until someone has
// decided to take it deliberately.
var noChurnExpectations = map[string]string{
	"GET /api/sessions/{id}/playlist": "AllowAPIGatewayInvoke-GET--api-sessions-id-playlist",
	"POST /api/issue":                 "AllowAPIGatewayInvoke-POST--api-issue",
	"GET /api/detect/{job_id}":        "AllowAPIGatewayInvoke-GET--api-detect-job_id",
}

// planned is the slice of the `terraform show -json` shape this test reads.
type planned struct {
	PlannedValues struct {
		RootModule struct {
			ChildModules []struct {
				Resources []struct {
					Type   string `json:"type"`
					Index  any    `json:"index"`
					Values struct {
						StatementID string `json:"statement_id"`
					} `json:"values"`
				} `json:"resources"`
			} `json:"child_modules"`
		} `json:"root_module"`
	} `json:"planned_values"`
}

// TestAPIGatewayHTTPStatementIDSanitization locks the statement_id sanitizer
// against route keys that are legal for API Gateway but not for AWS's
// statement_id charset.
//
// THE BUG THIS PREVENTS. The sanitizer replaced space, "/", "{" and "}" —
// every character a route key had ever contained in this fleet. A private
// consumer then added `GET /api/sessions/{id}/playlist.m3u8`, a file-extension
// route that API Gateway serves happily, and the "." passed straight into the
// statement_id. That consumer's whole dev stack could no longer plan, after
// the route change itself had already been reviewed and merged.
func TestAPIGatewayHTTPStatementIDSanitization(t *testing.T) {
	t.Parallel()

	fixtureDir := test_structure.CopyTerraformFolderToTemp(t, "..", filepath.Join("test", "fixtures", "api-gateway-http-statement-id"))
	terraformOptions := terraformOptions(t, &terraform.Options{
		TerraformDir: fixtureDir,
		PlanFilePath: filepath.Join(fixtureDir, "tfplan.bin"),
	})

	// This call is itself the primary assertion: the fixture's routes include
	// keys with ".", "~", ":" and "+", and before the fix the provider's
	// validator rejected them here, with no "Plan:" summary emitted at all.
	terraform.InitAndPlan(t, terraformOptions)

	raw := terraform.RunTerraformCommand(t, terraformOptions, "show", "-json", terraformOptions.PlanFilePath)

	var p planned
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		t.Fatalf("could not parse `terraform show -json` output: %v", err)
	}

	got := map[string]string{}
	for _, mod := range p.PlannedValues.RootModule.ChildModules {
		for _, res := range mod.Resources {
			if res.Type != "aws_lambda_permission" {
				continue
			}
			routeKey, ok := res.Index.(string)
			if !ok {
				t.Fatalf("aws_lambda_permission index was %T, not the route-key string this module keys it by", res.Index)
			}
			got[routeKey] = res.Values.StatementID
		}
	}

	// A fixture that silently stopped producing permissions would make every
	// assertion below vacuous — the classic way this kind of test rots.
	if len(got) != 8 {
		t.Fatalf("expected 8 lambda permissions in the plan, found %d — the fixture's routes or the module's lambda_routes filter changed, and the assertions below would be vacuous", len(got))
	}

	for routeKey, statementID := range got {
		if !statementIDCharset.MatchString(statementID) {
			t.Errorf("route %q produced statement_id %q, which AWS rejects: it must match %s", routeKey, statementID, statementIDCharset)
		}
		if len(statementID) > statementIDMaxLen {
			t.Errorf("route %q produced a %d-character statement_id, over AWS's limit of %d: %q", routeKey, len(statementID), statementIDMaxLen, statementID)
		}
	}

	for routeKey, want := range noChurnExpectations {
		if got[routeKey] != want {
			t.Errorf("route %q now produces statement_id %q, was %q.\n"+
				"statement_id forces replacement, so changing it destroys and recreates this lambda permission in EVERY api-gateway-http consumer. "+
				"If that migration is intended, update noChurnExpectations deliberately and say so in the PR; do not adjust it to make this pass.",
				routeKey, got[routeKey], want)
		}
	}
}
