package test

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// renderViewerRequest renders the module's CloudFront Function template with
// the given fixture variables and returns the resulting JavaScript.
//
// It asserts on the RENDERED artifact on purpose: viewer_request.js.tftpl
// carries `%{ if }` directives, so the file on disk is never what CloudFront
// actually runs, and a test that grepped the template could pass while every
// deployed site ran something else.
func renderViewerRequest(t *testing.T, vars map[string]interface{}) string {
	t.Helper()

	fixtureDir := test_structure.CopyTerraformFolderToTemp(t, "..", filepath.Join("test", "fixtures", "cloudfront-viewer-request-render"))
	opts := &terraform.Options{TerraformDir: fixtureDir, Vars: vars, NoColor: true}

	terraform.Init(t, opts)
	terraform.Apply(t, opts)

	return terraform.Output(t, opts, "code")
}

// viewerResult is the subset of a CloudFront Function's return value these
// tests assert on. A pass-through returns the request (which has `uri`); a
// generated response returns a status plus headers.
type viewerResult struct {
	StatusCode int    `json:"statusCode"`
	Location   string `json:"location"`
	URI        string `json:"uri"`
}

// runViewer executes the rendered function under node against one synthetic
// viewer-request event and reports what it returned.
func runViewer(t *testing.T, code, uri, querystring string, cookies map[string]string, host string) viewerResult {
	t.Helper()

	if _, err := exec.LookPath("node"); err != nil {
		t.Skip("node is not installed; skipping the viewer-request behaviour test")
	}

	event := map[string]interface{}{
		"request": map[string]interface{}{
			"method":      "GET",
			"uri":         uri,
			"querystring": querystringForEvent(t, querystring),
			"headers":     map[string]interface{}{"host": map[string]string{"value": host}},
			"cookies":     cookiesForEvent(cookies),
		},
	}
	eventJSON, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("marshalling the synthetic event: %v", err)
	}

	// The rendered code is a bare `function handler(event)` declaration, the
	// shape CloudFront expects. Appending a driver makes it runnable as-is,
	// without editing the artifact under test.
	driver := code + `
const out = handler(JSON.parse(process.argv[2]));
process.stdout.write(JSON.stringify({
  statusCode: out.statusCode || 0,
  location: (out.headers && out.headers.location && out.headers.location.value) || "",
  uri: out.uri || "",
}));
`
	scriptPath := filepath.Join(t.TempDir(), "viewer_request.js")
	if err := os.WriteFile(scriptPath, []byte(driver), 0o600); err != nil {
		t.Fatalf("writing the rendered function: %v", err)
	}

	out, err := exec.Command("node", scriptPath, string(eventJSON)).CombinedOutput()
	if err != nil {
		t.Fatalf("node failed: %v\n%s", err, out)
	}

	var result viewerResult
	if err := json.Unmarshal(out, &result); err != nil {
		t.Fatalf("decoding the function's return value %q: %v", out, err)
	}
	return result
}

// querystringForEvent builds CloudFront's already-URL-DECODED
// { key: { value, multiValue? } } querystring shape from a raw `a=b&c=d`
// string, including the multiValue form for a repeated key.
//
// Emitted as pre-serialised JSON rather than a Go map on purpose:
// `json.Marshal` sorts map keys alphabetically, which would hand `node` the
// parameters in an order the viewer never sent and make this harness — not
// the function — responsible for any reordering. Real CloudFront builds the
// object in the order the query string had, and JS preserves string-key
// insertion order, so order is a property worth testing faithfully.
func querystringForEvent(t *testing.T, raw string) json.RawMessage {
	t.Helper()

	if raw == "" {
		return json.RawMessage("{}")
	}

	order := []string{}
	values := map[string][]string{}
	for _, pair := range strings.Split(raw, "&") {
		key, value, _ := strings.Cut(pair, "=")
		if _, seen := values[key]; !seen {
			order = append(order, key)
		}
		values[key] = append(values[key], value)
	}

	entries := make([]string, 0, len(order))
	for _, key := range order {
		keyJSON, err := json.Marshal(key)
		if err != nil {
			t.Fatalf("marshalling querystring key %q: %v", key, err)
		}

		got := values[key]
		valueJSON, err := json.Marshal(got[0])
		if err != nil {
			t.Fatalf("marshalling querystring value %q: %v", got[0], err)
		}
		entry := `{"value":` + string(valueJSON)

		if len(got) > 1 {
			multi := make([]string, 0, len(got))
			for _, one := range got {
				oneJSON, err := json.Marshal(one)
				if err != nil {
					t.Fatalf("marshalling querystring value %q: %v", one, err)
				}
				multi = append(multi, `{"value":`+string(oneJSON)+`}`)
			}
			entry += `,"multiValue":[` + strings.Join(multi, ",") + `]`
		}

		entries = append(entries, string(keyJSON)+":"+entry+"}")
	}

	return json.RawMessage("{" + strings.Join(entries, ",") + "}")
}

func cookiesForEvent(cookies map[string]string) map[string]interface{} {
	out := map[string]interface{}{}
	for name, value := range cookies {
		out[name] = map[string]string{"value": value}
	}
	return out
}

// TestViewerRequestRedirectsPreserveTheQueryString locks the module's
// redirect invariant.
//
// Every redirect the function GENERATES builds its own `location` header, so
// one built from `uri` alone silently drops `?a=b` — CloudFront only
// preserves a query string on requests it passes THROUGH to the origin. A
// hosted-checkout handoff, an OAuth callback and a password-reset link each
// carry their only state there, so a language or .html-canonicalisation hop
// in front of them loses it.
//
// Verified to fail before the fix: with `+ queryTail(request)` removed from
// any of the three redirect sites, the matching subtest reports a Location
// header with no query — language routing breaks 6 subtests, .html
// canonicalisation 2, the www redirect 1, and all 9 pass again once restored.
//
// Re-run that differential with `go test -count=1`. The template lives
// OUTSIDE this package and is read at run time by terraform, so Go's test
// cache cannot see an edit to it and will replay a stale `ok` — which looks
// exactly like a gate that cannot fail.
func TestViewerRequestRedirectsPreserveTheQueryString(t *testing.T) {
	t.Parallel()

	code := renderViewerRequest(t, map[string]interface{}{
		"canonicalize_html": true,
		"www_redirect_host": "example.test",
	})

	tests := []struct {
		name         string
		uri          string
		querystring  string
		host         string
		wantStatus   int
		wantLocation string
	}{
		{
			name:         "language routing keeps the query",
			uri:          "/mock-checkout",
			querystring:  "order=abc123&scenario=approved",
			host:         "example.test",
			wantStatus:   302,
			wantLocation: "/en/mock-checkout?order=abc123&scenario=approved",
		},
		{
			name:         "language routing on the root keeps the query",
			uri:          "/",
			querystring:  "ref=newsletter",
			host:         "example.test",
			wantStatus:   302,
			wantLocation: "/en/?ref=newsletter",
		},
		{
			name:         "html canonicalisation keeps the query",
			uri:          "/en/mock-checkout.html",
			querystring:  "order=abc123&scenario=approved",
			host:         "example.test",
			wantStatus:   301,
			wantLocation: "/en/mock-checkout?order=abc123&scenario=approved",
		},
		{
			name:         "index.html canonicalisation keeps the query",
			uri:          "/en/index.html",
			querystring:  "ref=newsletter",
			host:         "example.test",
			wantStatus:   301,
			wantLocation: "/en/?ref=newsletter",
		},
		{
			name:         "the www redirect keeps the query",
			uri:          "/en/order-success",
			querystring:  "order=abc123",
			host:         "www.example.test",
			wantStatus:   301,
			wantLocation: "https://example.test/en/order-success?order=abc123",
		},
		{
			name:         "a repeated key survives as every occurrence",
			uri:          "/catalog",
			querystring:  "tag=a&tag=b",
			host:         "example.test",
			wantStatus:   302,
			wantLocation: "/en/catalog?tag=a&tag=b",
		},
		{
			// CloudFront hands over DECODED values, so a value containing a
			// space, a `?` or an `=` must be re-encoded on the way back out
			// or the Location header gains structure the viewer never sent.
			// (A literal `&` cannot be expressed through this harness: in a
			// raw query string it IS the separator.)
			name:         "a decoded value is re-encoded, not concatenated raw",
			uri:          "/search",
			querystring:  "q=blue white?x=1",
			host:         "example.test",
			wantStatus:   302,
			wantLocation: "/en/search?q=blue%20white%3Fx%3D1",
		},
		{
			name:         "parameter order is preserved, not alphabetised",
			uri:          "/mock-checkout",
			querystring:  "z=last&a=first",
			host:         "example.test",
			wantStatus:   302,
			wantLocation: "/en/mock-checkout?z=last&a=first",
		},
		{
			name:         "a valueless parameter survives",
			uri:          "/catalog",
			querystring:  "debug",
			host:         "example.test",
			wantStatus:   302,
			wantLocation: "/en/catalog?debug=",
		},
		{
			name:         "no query string adds no stray question mark",
			uri:          "/mock-checkout",
			querystring:  "",
			host:         "example.test",
			wantStatus:   302,
			wantLocation: "/en/mock-checkout",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := runViewer(t, code, tc.uri, tc.querystring, nil, tc.host)
			if got.StatusCode != tc.wantStatus {
				t.Errorf("status: got %d, want %d (location %q)", got.StatusCode, tc.wantStatus, got.Location)
			}
			if got.Location != tc.wantLocation {
				t.Errorf("location:\n got %q\nwant %q", got.Location, tc.wantLocation)
			}
		})
	}
}

// TestViewerRequestDevAccessRedirectDropsTheToken pins the one deliberate
// exception to the invariant above: the magic-link hop must NOT forward its
// own `?token=<secret>` onto the landing URL, or the shared dev secret ends
// up in browser history, referrers and access logs.
func TestViewerRequestDevAccessRedirectDropsTheToken(t *testing.T) {
	t.Parallel()

	const secret = "s3cr3t-dev-token"
	code := renderViewerRequest(t, map[string]interface{}{
		"canonicalize_html": true,
		"dev_access_secret": secret,
	})

	got := runViewer(t, code, "/dev-access", "token="+secret, nil, "example.test")
	if got.StatusCode != 302 {
		t.Fatalf("status: got %d, want 302", got.StatusCode)
	}
	if got.Location != "/" {
		t.Errorf("the dev-access redirect must land on %q with no query; got %q", "/", got.Location)
	}
	if strings.Contains(got.Location, secret) {
		t.Errorf("the dev secret leaked into the redirect target: %q", got.Location)
	}
}

// TestViewerRequestPassthroughLeavesTheRequestAlone guards the other half:
// a passthrough path must reach the origin unmodified, where CloudFront
// carries the query string itself. Asserting it here keeps a future change
// to queryTail from accidentally turning a passthrough into a redirect.
func TestViewerRequestPassthroughLeavesTheRequestAlone(t *testing.T) {
	t.Parallel()

	code := renderViewerRequest(t, map[string]interface{}{"canonicalize_html": true})

	got := runViewer(t, code, "/api/orders", "order=abc123", nil, "example.test")
	if got.StatusCode != 0 {
		t.Errorf("a passthrough path must not be redirected; got status %d -> %q", got.StatusCode, got.Location)
	}
	if got.URI != "/api/orders" {
		t.Errorf("uri: got %q, want %q", got.URI, "/api/orders")
	}
}
