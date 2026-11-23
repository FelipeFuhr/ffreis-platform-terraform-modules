package test

import (
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// budgetActionThreshold / budgetActionSubscriber / budgetPlannedResource are the
// slice of `terraform show -json` this test reads.
type budgetActionThreshold struct {
	Type  string  `json:"action_threshold_type"`
	Value float64 `json:"action_threshold_value"`
}

type budgetActionSubscriber struct {
	Address          string `json:"address"`
	SubscriptionType string `json:"subscription_type"`
}

type budgetPlannedResource struct {
	Type   string `json:"type"`
	Values struct {
		ActionType       string                   `json:"action_type"`
		ApprovalModel    string                   `json:"approval_model"`
		NotificationType string                   `json:"notification_type"`
		ExecutionRoleARN string                   `json:"execution_role_arn"`
		ActionThreshold  []budgetActionThreshold  `json:"action_threshold"`
		Subscriber       []budgetActionSubscriber `json:"subscriber"`
	} `json:"values"`
}

type budgetPlanned struct {
	PlannedValues struct {
		RootModule struct {
			ChildModules []struct {
				Address   string                  `json:"address"`
				Resources []budgetPlannedResource `json:"resources"`
			} `json:"child_modules"`
		} `json:"root_module"`
	} `json:"planned_values"`
}

// budgetModulePlan is what this test asserts on, per module instance.
type budgetModulePlan struct {
	budgets int
	actions int
	roles   int
	action  *budgetPlannedResource
}

// TestBudgetAction locks the two properties that make the enforcement action
// safe to add to a module the whole fleet already consumes.
//
// THE GAP THIS CLOSES. modules/budget declared exactly one resource,
// aws_budgets_budget, with notification blocks only. So every budget in the
// fleet emailed on breach and changed nothing — see
// ffreis-genai-runtime/docs/DESIGN.md §6.3, which lists
// aws_budgets_budget_action as the one aggregate control that "would actually
// enforce" and records it as unused fleet-wide.
//
// Both assertions are plan-time and need no credentials, so they cost nothing.
func TestBudgetAction(t *testing.T) {
	t.Parallel()

	fixtureDir := test_structure.CopyTerraformFolderToTemp(t, "..", filepath.Join("test", "fixtures", "budget-action"))
	terraformOptions := terraformOptions(t, &terraform.Options{
		TerraformDir: fixtureDir,
		PlanFilePath: filepath.Join(fixtureDir, "tfplan.bin"),
	})

	// This call is itself an assertion. The notify_only instance must plan with
	// skip_requesting_account_id set — i.e. the action feature must not have
	// introduced an ungated aws_caller_identity that every existing notify-only
	// caller would now have to satisfy.
	terraform.InitAndPlan(t, terraformOptions)

	raw := terraform.RunTerraformCommand(t, terraformOptions, "show", "-json", terraformOptions.PlanFilePath)

	var p budgetPlanned
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		t.Fatalf("could not parse `terraform show -json` output: %v", err)
	}

	got := map[string]*budgetModulePlan{}
	for _, mod := range p.PlannedValues.RootModule.ChildModules {
		m := &budgetModulePlan{}
		got[mod.Address] = m
		for i := range mod.Resources {
			res := &mod.Resources[i]
			switch res.Type {
			case "aws_budgets_budget":
				m.budgets++
			case "aws_budgets_budget_action":
				m.actions++
				m.action = res
			case "aws_iam_role":
				m.roles++
			}
		}
	}

	// A fixture that stopped producing modules would make everything below
	// vacuous — the classic way this kind of test rots.
	if len(got) != 2 {
		t.Fatalf("expected 2 module instances in the plan, found %d: %v", len(got), got)
	}

	// ── Property 1: default OFF, so existing callers are unaffected. ───────
	n, ok := got["module.notify_only"]
	if !ok {
		t.Fatalf("module.notify_only missing from the plan; found %v", got)
	}
	if n.budgets != 1 {
		t.Errorf("notify-only budget planned %d aws_budgets_budget, want 1", n.budgets)
	}
	if n.actions != 0 {
		t.Errorf("notify-only budget planned %d aws_budgets_budget_action, want 0 — var.action defaults to null, "+
			"so a caller that never asked for enforcement must not get an action (its blast radius is a deliberate outage)", n.actions)
	}
	if n.roles != 0 {
		t.Errorf("notify-only budget planned %d aws_iam_role, want 0 — the execution role must be counted off with the action", n.roles)
	}

	// ── Property 2: opting in actually enforces. ───────────────────────────
	e, ok := got["module.enforcing"]
	if !ok {
		t.Fatalf("module.enforcing missing from the plan; found %v", got)
	}
	if e.actions != 1 {
		t.Fatalf("enforcing budget planned %d aws_budgets_budget_action, want 1", e.actions)
	}
	if e.roles != 0 {
		t.Errorf("enforcing budget planned %d aws_iam_role, want 0 — the fixture supplies execution_role_arn, "+
			"so the module must not also create one", e.roles)
	}
	if e.action == nil {
		t.Fatal("no aws_budgets_budget_action captured from module.enforcing")
	}

	v := e.action.Values
	if v.ActionType != "APPLY_IAM_POLICY" {
		t.Errorf("action_type = %q, want APPLY_IAM_POLICY for an `iam` action", v.ActionType)
	}
	// The whole point: MANUAL waits for a human and so enforces nothing on its
	// own, which is indistinguishable from the notify-only module this replaces.
	if v.ApprovalModel != "AUTOMATIC" {
		t.Errorf("approval_model = %q, want AUTOMATIC. Passing var.action is opting in to enforcement; "+
			"a MANUAL default would behave exactly like the notify-only module and reopen the gap this closes.", v.ApprovalModel)
	}
	if v.NotificationType != "ACTUAL" {
		t.Errorf("notification_type = %q, want ACTUAL — a FORECASTED default would stop spend on a projection, not a fact", v.NotificationType)
	}
	if len(v.ActionThreshold) != 1 {
		t.Fatalf("got %d action_threshold blocks, want 1", len(v.ActionThreshold))
	}
	if th := v.ActionThreshold[0]; th.Type != "PERCENTAGE" || th.Value != 100 {
		t.Errorf("action_threshold = %s/%v, want PERCENTAGE/100 — DESIGN.md §6.6 puts this at 100%% of a "+
			"deliberately generous limit, with the per-request guard handling the normal case", th.Type, th.Value)
	}
	if v.ExecutionRoleARN == "" {
		t.Error("action planned with an empty execution_role_arn; AWS Budgets cannot assume a role it was not given")
	}
	// Reversal is manual: AWS applies the action and never un-applies it, so
	// somebody has to be told it fired.
	if len(v.Subscriber) == 0 {
		t.Error("action planned with no subscriber; AWS requires one and the action is irreversible without a human")
	}
}
