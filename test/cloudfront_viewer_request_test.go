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
			// Pins that every parameter is emitted exactly once, in the order
			// of the querystring object `queryTail` is handed — nothing
			// dropped, nothing duplicated, nothing alphabetised on the way
			// out.
			//
			// It does NOT promise that a redirect preserves the order the
			// VIEWER sent, and nothing should rely on that: CloudFront builds
			// `request.querystring` as an object, and its key order is
			// arbitrary. Measured against a live distribution running this
			// function — `a=1&b=2` came back as `b=2&a=1`, `z=1&a=2&m=3` as
			// `m=3&a=2&z=1`, while `b=1&a=2` came back unchanged — so the
			// order is neither the source's nor alphabetical. That is
			// harmless (query parameters are an unordered set, and every
			// consumer reads them by name), but it is worth stating here so
			// the next reader does not take this subtest for an end-to-end
			// guarantee. The one ordering that IS guaranteed is within a
			// single repeated key, via `multiValue` — the subtest above.
			name:         "every parameter is emitted once, in the object's own order",
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

// flatModeVars renders the function the way a single-language site at the
// root configures it: no language prefixes, no default language, no
// passthrough prefixes and no country map.
//
// `passthrough_prefixes = []` matters. Every CloudFront `request.uri` starts
// with '/', so the PASSTHROUGH_PREFIXES loop matches `"/"` unconditionally
// and returns the request before any rewriting — which made cleanUrl
// unreachable for a site that tried to spell "pass everything through" that
// way. Flat-mode is the supported spelling instead.
func flatModeVars() map[string]interface{} {
	return map[string]interface{}{
		"canonicalize_html":    true,
		"lang_prefixes":        []string{},
		"default_lang":         "",
		"passthrough_prefixes": []string{},
		"country_to_lang":      map[string]string{},
	}
}

// TestViewerRequestFlatModeRewritesWithoutLanguageRouting pins flat-mode:
// with `lang_prefixes = []` the site is single-language and served at the
// root, so language routing is skipped and only clean-URL / directory-index
// rewriting applies.
//
// Before the flat-mode branch existed, `detectLang` returned DEFAULT_LANG
// (”), so the redirect target was '/' + ” + uri — i.e. '//<path>' — and
// cleanUrl was never reached at all. Every one of these cases 302'd instead.
func TestViewerRequestFlatModeRewritesWithoutLanguageRouting(t *testing.T) {
	t.Parallel()

	code := renderViewerRequest(t, flatModeVars())

	tests := []struct {
		name       string
		uri        string
		wantStatus int
		wantURI    string
	}{
		{
			name:       "the bare root resolves to the root index",
			uri:        "/",
			wantStatus: 0,
			wantURI:    "/index.html",
		},
		{
			name:       "an extensionless page gets its directory index",
			uri:        "/detector",
			wantStatus: 0,
			wantURI:    "/detector/index.html",
		},
		{
			name:       "a trailing slash gets the same index, not a redirect",
			uri:        "/detector/",
			wantStatus: 0,
			wantURI:    "/detector/index.html",
		},
		{
			name:       "a nested extensionless page gets its directory index",
			uri:        "/docs/getting-started",
			wantStatus: 0,
			wantURI:    "/docs/getting-started/index.html",
		},
		{
			name:       "a path with an extension passes through untouched",
			uri:        "/assets/style.css",
			wantStatus: 0,
			wantURI:    "/assets/style.css",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := runViewer(t, code, tc.uri, "", nil, "example.test")
			if got.StatusCode != tc.wantStatus {
				t.Errorf("status: got %d (location %q), want %d", got.StatusCode, got.Location, tc.wantStatus)
			}
			if got.URI != tc.wantURI {
				t.Errorf("uri:\n got %q\nwant %q", got.URI, tc.wantURI)
			}
		})
	}
}

// TestViewerRequestFlatModeCanonicalisesHtml checks that flat-mode still
// reaches the .html canonicalisation inside cleanUrl — the branch returns
// cleanUrl(), so the 301 must happen at the root with no language segment.
func TestViewerRequestFlatModeCanonicalisesHtml(t *testing.T) {
	t.Parallel()

	code := renderViewerRequest(t, flatModeVars())

	tests := []struct {
		name         string
		uri          string
		querystring  string
		wantLocation string
	}{
		{
			name:         "a .html page canonicalises to its extensionless form",
			uri:          "/detector.html",
			wantLocation: "/detector",
		},
		{
			name:         "index.html canonicalises to the root",
			uri:          "/index.html",
			wantLocation: "/",
		},
		{
			name:         "canonicalisation still carries the query string",
			uri:          "/detector.html",
			querystring:  "ref=newsletter",
			wantLocation: "/detector?ref=newsletter",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := runViewer(t, code, tc.uri, tc.querystring, nil, "example.test")
			if got.StatusCode != 301 {
				t.Errorf("status: got %d, want 301", got.StatusCode)
			}
			if got.Location != tc.wantLocation {
				t.Errorf("location:\n got %q\nwant %q", got.Location, tc.wantLocation)
			}
		})
	}
}

// TestViewerRequestFlatModeTerminatesInsteadOfLooping is the regression guard
// for the defect flat-mode exists to kill.
//
// With `lang_prefixes = []` on the previous template, the language redirect
// built '/' + DEFAULT_LANG + uri with DEFAULT_LANG = ”, so '/' became '//',
// which matched no language prefix and redirected again: '//' -> '///' ->
// '////', forever. Measured before the fix: 8 hops with no fixed point.
//
// Asserting "terminates" rather than "is not a 302" is deliberate. A fix
// that merely REORDERED the redirect would still satisfy a status assertion
// on the first hop while leaving the loop in place one step further along, so
// this follows the function's own Location headers to a fixed point.
func TestViewerRequestFlatModeTerminatesInsteadOfLooping(t *testing.T) {
	t.Parallel()

	code := renderViewerRequest(t, flatModeVars())

	for _, start := range []string{"/", "/detector", "/detector/", "/index.html", "/assets/style.css"} {
		t.Run(start, func(t *testing.T) {
			uri := start
			chain := []string{uri}

			// A browser gives up around 20 hops; 8 is well past any
			// legitimate chain here (the longest is .html -> clean -> origin).
			for hop := 0; hop < 8; hop++ {
				got := runViewer(t, code, uri, "", nil, "example.test")
				if got.StatusCode == 0 {
					return // reached the origin: terminated
				}
				if got.Location == "" || got.Location == uri {
					return // a self-target or bodyless response is also a fixed point
				}
				chain = append(chain, got.Location)
				uri = got.Location
			}

			t.Errorf("redirect loop: %s (no fixed point after 8 hops)", strings.Join(chain, " -> "))
		})
	}
}

// TestViewerRequestDevGateRunsBeforePassthroughInFlatMode pins the ordering
// of the security gate against the routing change.
//
// The flat-mode branch was inserted AFTER the passthrough loops, which are
// themselves after the cookie gate. That ordering is load-bearing: if the
// gate ever moved below passthrough (or below flat-mode's early return), a
// site with a passthrough prefix would serve unauthenticated traffic. So
// this asserts the gate still wins over both.
func TestViewerRequestDevGateRunsBeforePassthroughInFlatMode(t *testing.T) {
	t.Parallel()

	const secret = "s3cr3t-dev-token"

	vars := flatModeVars()
	vars["dev_access_secret"] = secret
	// A prefix that matches every URI: if passthrough were evaluated first,
	// every request below would reach the origin ungated.
	vars["passthrough_prefixes"] = []string{"/"}
	code := renderViewerRequest(t, vars)

	t.Run("an uncookied request is refused even on a passthrough prefix", func(t *testing.T) {
		for _, uri := range []string{"/", "/detector", "/detector/", "/assets/style.css"} {
			got := runViewer(t, code, uri, "", nil, "example.test")
			if got.StatusCode != 403 {
				t.Errorf("%s: got status %d (uri %q, location %q), want 403 — the dev gate must run before passthrough", uri, got.StatusCode, got.URI, got.Location)
			}
		}
	})

	t.Run("the magic link still mints the cookie and drops the token", func(t *testing.T) {
		got := runViewer(t, code, "/dev-access", "token="+secret, nil, "example.test")
		if got.StatusCode != 302 {
			t.Fatalf("status: got %d, want 302", got.StatusCode)
		}
		if got.Location != "/" {
			t.Errorf("location: got %q, want %q", got.Location, "/")
		}
		if strings.Contains(got.Location, secret) {
			t.Errorf("the dev secret leaked into the redirect target: %q", got.Location)
		}
	})

	t.Run("a wrong token is refused", func(t *testing.T) {
		got := runViewer(t, code, "/dev-access", "token=not-the-secret", nil, "example.test")
		if got.StatusCode != 403 {
			t.Errorf("status: got %d, want 403", got.StatusCode)
		}
	})

	t.Run("a cookied request is admitted", func(t *testing.T) {
		got := runViewer(t, code, "/detector", "", map[string]string{"dev_access": secret}, "example.test")
		// PASSTHROUGH_PREFIXES = ["/"] still short-circuits ahead of
		// flat-mode, so the request reaches the origin unrewritten. The point
		// here is that it is no longer 403: the gate admitted it.
		if got.StatusCode != 0 {
			t.Errorf("a cookied request must not be refused; got status %d -> %q", got.StatusCode, got.Location)
		}
	})
}

// TestViewerRequestDevGateInFlatModeWithoutPassthrough is the same gate
// without the catch-all prefix, so a cookied request actually reaches
// cleanUrl and the flat-mode rewrite is observable through the gate.
func TestViewerRequestDevGateInFlatModeWithoutPassthrough(t *testing.T) {
	t.Parallel()

	const secret = "s3cr3t-dev-token"

	vars := flatModeVars()
	vars["dev_access_secret"] = secret
	code := renderViewerRequest(t, vars)

	if got := runViewer(t, code, "/detector", "", nil, "example.test"); got.StatusCode != 403 {
		t.Errorf("uncookied: got status %d (uri %q), want 403", got.StatusCode, got.URI)
	}

	got := runViewer(t, code, "/detector", "", map[string]string{"dev_access": secret}, "example.test")
	if got.StatusCode != 0 {
		t.Fatalf("cookied: got status %d -> %q, want a passthrough to the origin", got.StatusCode, got.Location)
	}
	if got.URI != "/detector/index.html" {
		t.Errorf("cookied uri: got %q, want %q", got.URI, "/detector/index.html")
	}
}
