# Agent Context

**This repo:** `ffreis-platform-terraform-modules` — opinionated AWS Terraform modules
with hardcoded security baselines. 30+ modules covering KMS, IAM, VPC, S3, DynamoDB,
RDS, Lambda, ECS, SQS, SNS, etc.

## Non-obvious facts

- **Security defaults are on by default; callers opt OUT explicitly.** All free security
  controls (encryption, audit logging, public-access blocking) are enabled unless the
  caller sets an override variable. This is intentional — opt-out is visible in code
  review, opt-in is invisible.

- **No thin wrappers.** Modules encode platform decisions: RDS always uses Secrets
  Manager, SQS always has a DLQ, Lambda pre-creates a log group with retention. Do not
  add modules that just expose a provider resource with no added decisions.

- **Every bounded variable has a `validation` block.** Do not add variables without
  adding validation.

- **Tagging convention:** all modules accept `tags = module.tags.tags`. Use the tagging
  module — don't add free-form tag inputs.

- **Module source pinning:** consumers use git source with version tags:
  `git::https://github.com/FelipeFuhr/ffreis-platform-terraform-modules.git//modules/s3-bucket?ref=v1.2.0`

- **Terratest integration tests** apply real resources — they cost money and require
  AWS credentials. CI only runs them on `main`.

- **Module `README.md` files are partly generated.** Each has a hand-written section
  plus a `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` block produced by
  `terraform-docs markdown table --output-file README.md --output-mode inject
  <module-dir>` (pinned version tracked in `.github/workflows/tf-docs.yml`'s reusable
  caller). Never hand-edit inside the markers — edit the variable/output
  `description` in the `.tf` file and regenerate. The `tf-docs.yml` CI workflow fails
  the PR if the committed README drifts from a fresh run.

## Structure

```
modules/<name>/   ← exactly: variables.tf, main.tf, outputs.tf
test/             ← Terratest integration tests
```

## Build/test

```bash
# Validate all modules
for dir in modules/*/; do
  (cd "$dir" && terraform init -backend=false && terraform validate)
done
# Integration tests (requires AWS credentials, costs money)
go test ./test/... -v -timeout 30m
```

## Public repo — private-repo hygiene

This is a **public** GitHub repository. When writing commit messages, PR titles,
PR descriptions, or any other user-visible text, **never name private repos** —
website content, inventory, infra, Lambda, or data repos that are not publicly
listed. Use generic terms instead: "the fleet inventory", "a private consumer",
"internal infra", "private data repo", etc.

**No real production domain names or client/product brand names belong in this
repo either** — not in code, examples, descriptions, or docs, and not just the
internal dev subdomains. `modules/tagging`'s `domain` variable used to validate
against a closed enum that was a running public manifest of every real domain
the owner operates; it is now an open string + format-only regex (see
`modules/tagging/variables.tf`) specifically so a new product launch never
needs to touch this public repo again. When writing illustrative examples
(variable descriptions, usage blocks), use placeholders like `'my-product'`,
`'acme'`, `example.com` — never a real brand or domain, even one that's already
public elsewhere.

## Keeping this file current

- **If you discover a fact not reflected here:** add it before finishing your task.
- **If something here is wrong or outdated:** correct it in the same commit as the code change.
- **If you rename a file, command, or concept referenced here:** update the reference.
