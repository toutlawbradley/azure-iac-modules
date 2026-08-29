# Challenges & Decisions Log — Azure IaC Module Library

Bugs, decisions, reasoning — logged as they happen.
If it took more than 10 minutes to figure out, or if there
was a real fork in the road, it goes here.

## How to use this file

For a **decision** (a fork where more than one reasonable option existed):
```
### [Phase] Decision: <short title>
**Date:** 
**Options considered:** 
**Chose:** 
**Why:** 
**What I'd reconsider if:** (what would change this call later)
```

For a **bug / debugging session** (something broke or didn't behave as expected):
```
### [Phase] Bug: <short title>
**Date:** 
**Symptom:** 
**Root cause:** 
**Fix:** 
**Lesson:** (what would make me catch this faster next time)
```

Log entries in the order they happen. Don't clean them up to look smarter in hindsight —
the wrong turns are the useful part.

---

## Phase 0 — Foundation

### [Phase 0] Decision: Terraform vs. Bicep

**Date:** 2026-08-09
**Options considered:** Terraform, Bicep
**Chose:** Terraform
**Why:** _(fill in: the state-file/multi-cloud reasoning, the roadmap sequencing —
Security+ → AZ-104 → HashiCorp Terraform Associate → Kubernetes — and why that made Terraform
the tool that compounds with what's already planned, in your own words. See full ADR in
`docs/adr/0001-terraform-vs-bicep.md` for the formal version of this.)*
**What I'd reconsider if:** _(fill in: e.g. if the roadmap shifted toward Azure-only work
long-term, or if a future employer's stack were Bicep-first)*

---

### [Phase 0] Decision: State backend

**Date:** 2026-08-09
**Options considered:** Local state, remote state (Azure Storage backend with locking)
**Chose:** Remote state (Azure Storage), bootstrapped via a small, separate Terraform config in
`bootstrap/` that intentionally uses local state
**Why:** Local state has two real failure modes that don't show up until they happen: durability
(if the machine holding the state file dies or gets wiped, Terraform loses all record of what it
created, and recovery means manual reconciliation or a full rebuild) and concurrency (nothing
stops two simultaneous `terraform apply` runs — e.g. once from a laptop and once from CI — from
reading and writing the same state file at once and corrupting it). A remote Azure Storage
backend solves both: Azure replicates and durably stores the blob, and the backend supports a
lease-based lock so a second apply is rejected while one is already running. Since this project
has CI validation from Phase 0 onward, there are at least two potential "appliers" (me locally,
CI eventually) from day one, so local state was never a realistic option for the real modules.
The one exception is the bootstrap step itself: it creates the storage account that everything
else's state will live in, so nothing exists yet for *it* to point at. That step is low-stakes
and rarely re-run, so local state there is an accepted, deliberate exception rather than an
oversight.
**What I'd reconsider if:** N/A

---

### [Phase 0] Decision: CI security scanning — Trivy vs. Checkov, and GuardLine's role

**Date:** 2026-08-09
**Options considered:** Checkov, Trivy (tfsec ruled out — deprecated, merged into Trivy)
**Chose:** Trivy for Terraform/infrastructure scanning; GuardLine (existing project) retained for
scanning CI/CD pipeline config (`.github/workflows/*.yml`) and any future Dockerfiles — a
different layer than Trivy, not a duplicate of it
**Why:** Checkov and Trivy are close on Terraform-specific coverage — Checkov has more raw rules,
but Trivy is close enough for this project's needs and adds container/image scanning as the same
tool. Since AKS is already in scope (Module 2) and container image scanning will be relevant once
real workloads run on it, picking Trivy now means the container-scanning skill is learned early
and reused later, rather than needing a second tool picked up from scratch in Phase 2. Cost was a
non-factor — both are free and open source; the commercial option (Snyk IaC) wasn't a real
contender. GuardLine was kept in the pipeline, but pointed at a different target than Trivy: its
secrets-detection and config-auditing categories would have substantially overlapped with
Checkov/Trivy's built-in secrets and misconfiguration checks if run against the same Terraform
files, but GuardLine's config-risk category (insecure defaults in CI/CD pipeline files) covers
ground neither Trivy nor Checkov's primary job addresses — auditing the pipeline definition
itself, not the infrastructure it deploys. That split (Trivy audits what the pipeline deploys,
GuardLine audits the pipeline) is a real, non-redundant division of labor and a legitimate
narrative link back to GuardLine rather than a manufactured one.
**What I'd reconsider if:** N/A

---

### [Phase 0] Decision: Resource naming convention

**Date:** 2026-08-09
**Options considered:** Ad-hoc naming, Microsoft Cloud Adoption Framework (CAF) pattern
**Chose:** CAF pattern — `{type}-{workload}-{environment}-{region}-{instance}`,
e.g. `rg-iacmods-dev-eus-001`. Key Vault uses a Terraform `random` provider suffix instead of a
fixed instance number.
**Why:** CAF is Microsoft's own recommended naming standard and is directly reflected in AZ-104
material, so following it reinforces cert study the same way the rest of this project is meant
to. It also signals real platform knowledge (environment separation, resource-type prefixes)
rather than ad-hoc names that don't communicate anything about what a resource is or where it
sits. Key Vault needed an exception to the plain instance-number pattern: Azure enforces a
24-character limit and global uniqueness (across all of Azure, not just this subscription) on
Key Vault names specifically, and a fixed, guessable instance number like `-001` doesn't solve
uniqueness, only length. A Terraform-generated random suffix (via the `random` provider) solves
uniqueness without requiring manual coordination, and the generated value persists in state so
it doesn't change on every subsequent apply.
**What I'd reconsider if:** N/A

---

## Bootstrap — Remote State Setup

### [Bootstrap] Bug: `storage_account_name` deprecated on `azurerm_storage_container`

**Date:** 2026-08-29
**Symptom:** `terraform plan` on the `azurerm_storage_container` resource returned a deprecation
warning for `storage_account_name`, pointing at `storage_account_id` instead.
**Root cause:** Newer versions of the AzureRM provider are moving several resources away from
referencing related resources by name (a string, not guaranteed unique across subscriptions)
toward referencing them by ID (the full `/subscriptions/.../resourceGroups/...` path, which is
always globally unique). `storage_account_name` on `azurerm_storage_container` is one of the
arguments affected by that shift.
**Fix:** Changed `storage_account_name = azurerm_storage_account.main.name` to
`storage_account_id = azurerm_storage_account.main.id`, same reference pattern, just chaining
to `.id` instead of `.name`.
**Lesson:** Deprecation warnings in provider output are worth reading and fixing immediately,
not ignoring — they usually reflect a real change in the underlying Azure API, not just a
provider style preference. Also confirms a broader pattern to watch for going forward: newer
provider versions increasingly prefer ID-based references over name-based ones.

---

### [Bootstrap] Bug: Storage account created with public network access enabled by default

**Date:** 2026-08-29
**Symptom:** After successfully applying the bootstrap config, checked the storage account in
the Azure Portal and found "Public network access: Enabled" and "Blob anonymous access:
Enabled" — neither of which was intended.
**Root cause:** `container_access_type = "private"` on the `azurerm_storage_container` resource
only controls anonymous *read* access to that specific container's contents. It does not control
whether the *storage account itself* is reachable from the public internet at all — that's a
separate, higher-level setting (`public_network_access_enabled`) that defaults to `true` in the
AzureRM provider unless explicitly set otherwise. Since the bootstrap config never set this
argument, it silently inherited the provider's permissive default rather than a secure one.
**Fix:** Added `public_network_access_enabled = false` to the `azurerm_storage_account` resource
block, then re-applied. Verified the fix by checking the Azure Portal directly rather than
trusting the Terraform apply output alone — confirmed "Public network access: Disabled" after
re-applying.
**Lesson:** Terraform provider defaults are not the same thing as secure defaults — they often
reflect whatever Azure's own platform default is, which tends to favor ease-of-use over security.
Any argument controlling public exposure should be set explicitly, never left to the provider's
default, and checked against the real deployed resource in the portal, not just assumed correct
because `apply` succeeded. This is the class of misconfiguration Trivy is meant to catch
in CI going forward — a real, concrete first case for why that scanner is in the pipeline.

---

<!-- New entries go below this line, in chronological order -->