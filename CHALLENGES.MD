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

### [Phase 1] Decision: "Allow" Port 80 rather than "Deny" 

**Date:** 2026-09-06
**Options considered:** Allowing inbound Port 80, Denying inbound Port 80
**Chose:** "Allow" inbound Port 80
**Why:** Allowing port 80 to redirect to 443 at the application layer is more forgiving for users, standard practice for most public-facing web services. The cost: slightly more surface area open at the network layer, though nothing sensitive is actually exposed since the redirect happens before any real data is served. Denying Port 80 is most secure on paper, nothing insecure can ever happen on this port because it's simply unreachable. The real cost: any user who types a plain http:// URL, or any legacy client/bookmark/link that doesn't already specify HTTPS, just gets a hard connection failure instead of a smooth redirect. This is a usability regression, not just a theoretical one. Therefore, allowing port 80 seems like the best option for the current firewall rules.
**What I'd reconsider if:** N/A

---

## Phase 2 — AKS Module
 
### [Phase 2] Decision: RBAC over ABAC, MAC, or JIT for the AKS managed identity
 
**Date:** 2026-09-07
**Options considered:** RBAC (Role-Based Access Control), ABAC (Attribute-Based Access Control),
MAC (Mandatory Access Control), JIT (Just-In-Time access)
**Chose:** RBAC via a SystemAssigned managed identity
**Why:** AKS needs its own identity because the cluster actively makes Azure API calls on its
own, outside of anything I directly trigger — provisioning a load balancer when a `LoadBalancer`
service is created, attaching a disk when a workload needs persistent storage. Any time something
makes API calls to Azure, Azure needs to know who's asking and what they're allowed to do, so the
cluster needs a real identity, not just my own credentials.
A SystemAssigned managed identity handles the "who" — Azure creates and manages its lifecycle
automatically, no credential for me to generate, store, or rotate by hand. But an identity alone
carries zero permissions; permissions come from a separate mechanism: a role assignment, which
states that a specific identity is allowed to do specific things, on a specific scope. That's
RBAC — a predefined bundle of permissions (a "role") assigned to an identity, kept as narrow as
the job actually requires.
I considered the alternatives because they're all real Azure/security concepts, not because RBAC
was assumed by default:
- ABAC evaluates permissions dynamically based on attributes (time, resource tags, request
  conditions) rather than a fixed role. Azure supports it as a real, newer feature, but it solves
  a more complex problem than AKS actually has here — AKS's need (manage networking resources in
  a specific resource group) is static and well-understood, not conditional. ABAC's extra
  flexibility wouldn't buy anything, only add complexity.
- MAC (centrally enforced, non-overridable policy, e.g. classification levels) doesn't have a
  direct equivalent in Azure's IAM model the way Security+ teaches it for OS-level or classified
  systems. Azure's closest parallel (resource locks, Azure Policy) is a different, complementary
  layer, not a substitute for RBAC here.
- JIT (temporary, on-demand elevated access, e.g. Azure PIM) is built for occasional *human*
  privileged access, not a continuously-running system. AKS needs its permissions constantly, for
  as long as the cluster is managing workloads — JIT's expiring-access model would actually break
  normal cluster operation rather than protect anything.
**What I'd reconsider if:** N/A
---
 
### [Phase 2] Bug: Provider install failure — architecture mismatch red herring, then real disk space issue
 
**Date:** 2026-09-07
**Symptom:** `terraform plan` in the AKS+networking scratch test harness failed with
"Unrecognized remote plugin message... failed to negotiate the initial go-plugin protocol
handshake," pointing at a `darwin_amd64` provider binary.
**Root cause:** Initially suspected an Apple Silicon vs. Intel architecture mismatch, since the
error mentioned `darwin_amd64`. Confirmed via `uname -m` that the machine is actually genuinely
Intel (`x86_64`), ruling that theory out. Deleting `.terraform`/`.terraform.lock.hcl` and
re-running `init` surfaced the real cause on the next attempt: `no space left on device` while
writing the provider binary — the disk was at 97% capacity with only ~412Mi free. The original
handshake failure was most likely a corrupted/incomplete provider download caused by the same
underlying low-disk-space condition, not an architecture problem at all.
**Fix:** Freed up disk space, then re-ran `terraform init` from the correct scratch directory;
provider installed cleanly and `terraform plan` succeeded, showing 9 resources to add across both
the networking and AKS modules with correct cross-module wiring (`vnet_subnet_id` correctly
resolving from the networking module's output).
**Lesson:** Don't commit to the first plausible-sounding diagnosis — the architecture theory fit
the error message's surface details but fell apart on a two-second verification (`uname -m`).
Disk space is worth checking early for any "plugin failed to install/run" style error, since a
failed or truncated write during provider installation can produce confusing, seemingly unrelated
error messages on the next attempt rather than a clear "disk full" message the first time.
 
---
 
### [Phase 2] Decision: Azure SQL Database over PostgreSQL
 
**Date:** 2026-09-11
**Options considered:** Azure Database for PostgreSQL, Azure SQL Database, reusing a plain
storage account instead of a database module
**Chose:** Azure SQL Database
**Why:** The project's original scope left this module as an open "storage or database"
decision. Storage was ruled out in favor of a real database specifically to learn something new
rather than repeat the storage-account pattern already built in the bootstrap module. Between the
two database options, choosing Azure SQL means this module reinforces material
already being studied independently. PostgreSQL remains a legitimate, arguably
more common choice in newer/cloud-native shops, but doesn't carry that specific cert-overlap
benefit.
**What I'd reconsider if:** N/A
 
---
 
### [Phase 2] Decision: Generate the SQL admin password with `random_password`, never type or store it as plaintext
 
**Date:** 2026-09-19
**Options considered:** Typing the password directly into Terraform code (rejected outright —
same class of mistake GuardLine exists to catch), storing it in a gitignored `.tfvars` file,
generating it with the `random` provider's `random_password` resource
**Chose:** `random_password`, generated once by Terraform, referenced directly by the SQL server
resource, and exposed as a sensitive output for the future Key Vault module to consume
**Why:** A gitignored `.tfvars` file solves "don't commit the secret to GitHub," but the secret
still exists in plaintext somewhere, and a human still has to choose and type it at some point.
Generating the password with `random_password` means no human ever sees or types the raw value at
any point — it's created once by Terraform, persisted in state (same durability reasoning as the
Key Vault naming random suffix from Phase 0), and referenced directly by `.result`. The output is
marked `sensitive = true` so it never prints in plain text during `plan` or `apply`. This sets up the same
output-to-input handoff pattern used between networking and AKS: the database module generates
and exposes the password, and the Key Vault module (next) will take it as an input and store it
as an actual secret, closing the loop.
**What I'd reconsider if:** N/A
 
---
 
### [Phase 2] Bug: SQL server defaulted to public network access enabled
 
**Date:** 2026-09-19
**Symptom:** `terraform plan` for `azurerm_mssql_server` showed `public_network_access_enabled =
true`, even though nothing in the configuration explicitly requested public access.
**Root cause:** Same underlying pattern as the bootstrap storage account issue from Phase 0 —
`azurerm_mssql_server` defaults to public network access enabled in the AzureRM provider unless
explicitly set otherwise. Provider defaults reflect Azure's own platform default, which favors
ease-of-use over security, not the reverse.
**Fix:** Added `public_network_access_enabled = false` to the `azurerm_mssql_server` resource
block before ever applying it.
**Lesson:** This is the same gap caught previously on the storage account, but this time it was
anticipated proactively rather than discovered after the fact in the Azure Portal — a direct
demonstration that "check public network access defaults on every resource type that has them"
generalized into a real habit rather than a one-off fix. Worth treating any Azure resource with a
`public_network_access_enabled`-style argument as guilty until proven innocent: verify and set it
explicitly, don't trust the default.
 
---
 
## Phase 3-adjacent — First Real Full-Stack Deploy
 
### [Deploy] Bug: Cascading failures from a mid-flight region change
 
**Date:** 2026-09-19
**Symptom:** A real `terraform apply` of all four modules together initially failed on three
unrelated errors at once: AKS rejected `Standard_B2s` as an unavailable VM size for the
subscription, Azure SQL Server rejected `eastus` with "Provisioning is restricted in this
region," and the Key Vault secret write failed with a 403 (RBAC, addressed separately below).
Fixing the region by changing `location` to `eastus2` across modules then triggered a second,
different wave of failures: `SubnetNotFound` on AKS, a `409 Conflict` on the SQL server (name
already reserved in `eastus` from the first failed attempt), and `VaultNotFound` on the secret.
**Root cause:** Changing `location` on already-created resources (VNet, NSGs, the vault) forces
Terraform to destroy and recreate them (`must be replaced`), not just update them in place. The
destroy/recreate cycle wasn't instantaneous, so dependent resources (AKS's subnet reference, the
Key Vault secret write) fired before their dependencies had finished rebuilding in the new
region, producing "not found" errors that looked unrelated but were actually just a timing/
ordering symptom of the region change itself. Separately, Azure SQL Server names are globally
unique and sticky to their original region — the first failed attempt had already reserved
`sql-iacmods-dev-eus2-001` against `eastus`, so recreating it in `eastus2` under the same name
was rejected outright; a new name was required. AKS also failed separately with
`ServiceCidrOverlapExistingSubnetsCidr`, since it defaults to `10.0.0.0/16` for internal service
networking, directly overlapping the VNet's own `10.0.0.0/16` address space.
**Fix:** Renamed the SQL server to `sql-iacmods-dev-001` (dropping the region from the name
entirely, decoupling database `location` into its own variable independent of the other
modules). Added an explicit `network_profile` block to the AKS cluster with `service_cidr =
"10.1.0.0/16"`, non-overlapping with the VNet. Re-ran `apply`, letting the region-driven
recreation fully settle before dependent resources retried.
**Lesson:** A region change on live resources is not a simple in-place edit — it's a real
destroy-and-recreate with real ordering implications for anything downstream. Globally-unique
resource names (SQL servers, same class of constraint as storage accounts and Key Vaults) can
get "stuck" against a failed attempt's region and need a genuinely new name, not just a retry.
AKS's internal service CIDR needs to be explicitly set to a range outside the VNet's own address
space; it doesn't infer this automatically.
 
---
 
### [Deploy] Bug: Key Vault public network access blocked Terraform's own secret write
 
**Date:** 2026-09-19
**Symptom:** After fixing the region issues, the Key Vault secret write failed with a 403:
"Public network access is disabled and request is not from a trusted service nor via an approved
private link."
**Root cause:** `public_network_access_enabled = false` on the vault (a deliberate hardening
choice, same pattern as the storage account and SQL server) blocks all data-plane traffic,
including from the machine running Terraform itself, since it isn't "a trusted service" and isn't
connecting via a private endpoint (the private-endpoints subnet exists in the networking module,
but nothing is actually wired to route through it yet). This is a genuine distinction between the
management plane (creating the vault itself, unaffected) and the data plane (writing secrets
into it, blocked).
**Fix:** Temporarily set `public_network_access_enabled = true` for this verification deploy,
given the time-boxed nature of the free-credit window. Properly wiring a private endpoint through
the existing private-endpoints subnet is real, deliberate future work, not something to rush
under time pressure.
**Lesson:** Locking down public access is the secure choice, but it also blocks your own tooling
unless that tooling runs from inside the VNet or through a private endpoint. This is a real,
common production tension, not a mistake — the fix is architectural (private endpoints, or
running Terraform from a trusted network), not just flipping the setting back on permanently.
 
---
 
### [Deploy] Bug: Accidentally regressed AKS's Key Vault role from least-privilege to broad access
 
**Date:** 2026-09-19
**Symptom:** After a real deploy, the Key Vault's Role Assignments page showed only "Key Vault
Secrets Officer" assigned to my own account, with no "Key Vault Secrets User" assignment for
AKS's managed identity anywhere — even though `terraform plan` showed the `aks_kv_access` role
assignment resource existing with a real ID and no drift.
**Root cause:** While troubleshooting the earlier 403 (Terraform's own identity lacking write
access), I edited the AKS role assignment's `role_definition_name` from `"Key Vault Secrets
User"` to `"Key Vault Secrets Officer"` instead of adding a second, separate role assignment for
my own identity — collapsing two distinct-purpose assignments (AKS's narrow read access, my own
broader write access) into one, and silently granting AKS's identity far more privilege than it
actually needs (write and delete, when it only ever needs to read).
**Fix:** Restored two separate `azurerm_role_assignment` resources: `aks_kv_access` (Key Vault
Secrets User, scoped to AKS's `principal_id`) and a new `terraform_kv_access` (Key Vault Secrets
Officer, scoped to `data.azurerm_client_config.current.object_id`, my own identity). Re-applied
and confirmed via the portal: two separate entries, correctly scoped, AKS's managed identity
showing specifically under "Key Vault Secrets User."
**Lesson:** Under debugging pressure, it's easy to "fix" an access error by broadening the
existing assignment rather than adding the narrower one you actually need. Caught only by going
back to check the portal directly rather than trusting that a `plan` showing "no changes" meant
the architecture was still correct — the assignment can be technically unchanged in state while
still being the wrong assignment. This directly undermines the least-privilege reasoning already
logged for the original RBAC decision if left uncaught.
 
---
 
### [Deploy] Bug: RBAC propagation delay blocked `terraform destroy`
 
**Date:** 2026-09-19
**Symptom:** After restoring the correct role assignments, `terraform destroy` failed repeatedly
(across three separate attempts, with real time elapsed between them) with 403 errors reading and
deleting the Key Vault secret, even though the portal confirmed the correct role assignments were
in place.
**Root cause:** Likely RBAC propagation delay following the recent role assignment change,
though this couldn't be conclusively confirmed even after several minutes' wait — the error
message itself explicitly suggested this ("if role assignments... were changed recently, please
observe propagation time"), but a genuine multi-minute wait didn't resolve it.
**Fix:** Deleted the Key Vault directly through the Azure Portal instead of via Terraform, then
re-ran `terraform destroy`, which correctly recognized the vault no longer existed and completed
cleanup without further permission checks against it.
**Lesson:** When a resource is stuck on its own permissions mid-teardown, deleting it directly
through the portal and letting Terraform reconcile afterward is a legitimate, pragmatic escape
hatch — Terraform doesn't need to be the tool that removes every resource if a permissions
deadlock makes that impractical.
 
---
 
## CI Pipeline
 
### [CI] Decision: Built the Phase 0-specified pipeline (fmt/validate/tflint/Trivy/GuardLine)
 
**Date:** 2026-09-19
**Options considered:** N/A — this implements the tooling already decided in ADR-0003 and the
original Phase 0 scope, not a new tool choice.
**Chose:** A matrix job running `terraform fmt -check`, `terraform init -backend=false`,
`terraform validate`, and `tflint` once per module folder (bootstrap, networking, aks, database,
key-vault); a separate job running Trivy's config scan across the whole repo with SARIF output to
GitHub's Security tab; a separate job running GuardLine (the existing published Action) against
this repo's own `.github/workflows/*.yml`, matching ADR-0003's division of labor.
**Why:** Validation runs per-module and without a real backend connection specifically so CI
doesn't need Azure credentials just to check syntax and catch obvious misconfigurations early and
cheaply. Trivy and GuardLine stay as separate jobs scanning separate targets (infrastructure vs.
pipeline config), consistent with the non-redundant split already reasoned through in ADR-0003.
**What I'd reconsider if:** N/A
 
---
 
## CI Pipeline — First Run Debugging
 
### [CI] Bug: First CI run failed across every module with identical exit codes
 
**Date:** 2026-09-19
**Symptom:** The first push after adding `ci.yml` failed all five module jobs simultaneously,
each with `terraform fmt -check` exiting code 3.
**Root cause:** Every module's HCL had been hand-written and hand-edited across several weeks
without an auto-formatting editor extension, so small inconsistencies (spacing, alignment)
accumulated everywhere. `terraform fmt -check` was working correctly; it was surfacing genuine
formatting drift, not failing spuriously.
**Fix:** Ran `terraform fmt -recursive` from the repo root to auto-correct every file in one pass,
then committed the whitespace-only diff.
**Lesson:** Uniform failures across otherwise-unrelated files point at something structural (a
missing setting, an environment mismatch, a style-only check) rather than five separate content
bugs. Worth checking the pattern of the failure before diving into any one file.
 
---
 
### [CI] Bug: `node_provisioning_profile` required by CI's provider version but never enforced locally
 
**Date:** 2026-09-19
**Symptom:** `terraform validate` in CI failed on the AKS module with "At least 1
`node_provisioning_profile` blocks are required" — a block that had never existed in the
resource, and had never been required during any local `plan`/`apply`, including the deploy
earlier the same day.
**Root cause:** CI resolves providers independently in each module folder; without a committed,
consistent lock file enforcing an exact AzureRM version across every module, CI could resolve a
newer provider release than the one tested locally, and that newer release made this block
mandatory rather than optional.
**Fix:** Added `node_provisioning_profile { mode = "Manual" }` to the AKS cluster resource.
**Lesson:** A local environment and a CI environment can silently diverge on provider versions
even when the `.tf` files themselves are identical. A passing local `plan` is not proof CI will
pass, and vice versa.
 
---
 
### [CI] Bug: Duplicate `required_providers` blocks introduced while fixing a tflint warning
 
**Date:** 2026-09-19
**Symptom:** After adding `required_version` to satisfy a tflint warning, `terraform init` in CI
failed with "Duplicate required providers configuration... a module may have only one required
providers configuration."
**Root cause:** The fix was applied as a second, separate `terraform { required_providers {...} }`
block pasted into the file, rather than merged into the single existing block. The same mistake
recurred separately for the `random` provider in `database` and `key-vault`, which had their own
provider declaration living in a second block rather than consolidated with `azurerm`.
**Fix:** Merged every module down to exactly one `terraform {}` block, with `required_version`
and all providers (`azurerm`, and `random` where used) declared together inside a single
`required_providers` block.
**Lesson:** "Add X" instructions are ambiguous between "add a new block" and "add a line to the
existing block" — worth being explicit about which is meant, since the two produce structurally
different, sometimes conflicting configurations.
 
---
 
## Trivy Hardening Pass
 
### [Hardening] Decision: Fixed the fast, self-contained Trivy findings; deferred the ones needing new infrastructure
 
**Date:** 2026-09-19
**Options considered:** Fix all 18 findings immediately, fix none and defer everything, or
triage by whether a fix is a config change to an existing resource versus one that requires
adding new, independent infrastructure.
**Chose:** Fixed in place: storage account network rules (default deny), infrastructure
encryption, and geo-redundant replication; Key Vault purge protection, network ACLs, and secret
content type/expiration; AKS network policy and a Log Analytics Workspace with `oms_agent` for
cluster logging. Deferred, with reasoning recorded here rather than left unexplained: AKS API
server authorized IP ranges, AKS private cluster mode, the Azure Policy add-on, and a dedicated
disk encryption set for AKS; SQL Server extended auditing.
**Why:** The fixed items were each a small, additive change to a resource that already existed,
with no new dependency graph to design. The deferred items each require standing up
infrastructure that doesn't exist yet and wasn't part of this pass's scope — a storage account
dedicated to audit logs, App Registrations and service principals for Azure AD-integrated RBAC,
a policy assignment, a disk encryption set tied back into Key Vault. Building any of those
properly, rather than half-wiring them under momentum at the end of a long session, is worth
treating as separate, deliberate work.
**What I'd reconsider if:** this project needed to demonstrate compliance with a specific
framework (e.g. HIPAA technical safeguards) rather than general hardening — at that point the
deferred items, especially audit logging and private cluster access, would move from "nice to
have" to "actually required."
 
---
 
### [Hardening] Decision: Accepted NSG unrestricted ingress on the AKS subnet as intentional, not a gap
 
**Date:** 2026-09-19
**Options considered:** Restrict `source_address_prefix` on the AKS NSG's inbound rules to a
specific range, or leave it as `"*"` and document the reasoning.
**Chose:** Left as `"*"`, documented here rather than silently accepted.
**Why:** These two rules (allow 443, allow 80) exist specifically to accept public web traffic
into the cluster through its load balancer — that is the whole purpose of the ingress path, not
an oversight. A load balancer fronting a public service has to accept connections from any client
on the internet by design; scoping the source to a fixed range would defeat the point of exposing
a public-facing service at all. This is different in kind from the private-endpoints NSG, whose
source is correctly scoped to the AKS subnet specifically, since that traffic genuinely is
internal-only.
**What I'd reconsider if:** the workload behind this ingress point were ever internal-only rather
than public-facing, in which case scoping the source down would be the correct fix rather than
an unnecessary restriction.
 
---
 
## Remote Backend — First Real Use
 
### [Backend] Bug: `examples/integration/` couldn't authenticate to the remote backend — a long chase through the wrong layers before finding the real cause
 
**Date:** 2026-09-20
**Symptom:** The first `terraform init` against the real remote backend (bootstrap's storage
account) failed with a 403 `AuthorizationFailure` on "listing blobs." This was the first genuine
use of the remote backend in the whole project — every prior `init`, including all of Phase 1 and
Phase 2's scratch harnesses, used local state, so this exact failure mode had never been
exercised before.
**Root cause, and the order findings actually came in:**
1. First suspected RBAC: the identity running Terraform had never been granted a data-plane role
   on the storage account (subscription-level Owner does not grant blob data access — a real,
   separate finding, confirmed via the portal's Role Assignments page showing no
   "Storage Blob Data" role at all). Added `azurerm_role_assignment` granting
   `Storage Blob Data Contributor`, scoped to the storage account. This was a real, necessary fix,
   but not sufficient on its own.
2. Still failed after the role assignment (confirmed present and correctly scoped in the portal)
   and after waiting well past any reasonable RBAC propagation window. Suspected the network rule
   next: added an explicit IP allow-list (`network_rules`) with `default_action = "Deny"`.
3. Attempted to isolate network vs. permissions by temporarily setting
   `default_action = "Allow"` — but the `apply` for that change had silently not taken effect
   (confirmed later via `az storage account show --query networkRuleSet`, which showed
   `defaultAction: "Deny"` still live, while Terraform's own plan believed it needed to make that
   exact change — a real drift between assumed and actual state that produced a false negative
   in the isolation test).
4. Re-ran the network rule change properly, confirmed independently via the Azure CLI (not
   Terraform) that `defaultAction` was genuinely `"Allow"` — and the exact same 403 persisted.
   This conclusively ruled out both RBAC and the network rule as the actual cause.
5. The real cause: `public_network_access_enabled = false` on the storage account itself — a
   setting applied in Phase 0/bootstrap, in the project's very first week, that disables the
   entire public data-plane endpoint outright, regardless of what `network_rules` or RBAC role
   assignments say. This is the identical class of issue hit with Key Vault's secret write
   earlier in the project, just on a different resource, and not connected to this failure until
   checked directly via `az storage account show --query publicNetworkAccess`.
**Fix:** Set `public_network_access_enabled = true` on the bootstrap storage account. `init`
succeeded immediately afterward.
**Lesson:** `public_network_access_enabled` and `network_rules.default_action` are two separate,
independent gates, and the former overrides the latter entirely when disabled — this is the
second time this exact layering has caused a debugging detour (Key Vault, then storage), and is
worth checking first, not last, any time a data-plane 403 shows up on a resource with either
setting configured. Separately: never trust that an `apply` "worked" based on the plan alone once
there's any doubt — independently verifying live state via the Azure CLI (not just Terraform's
own state or plan output) was what actually broke the stalemate here, after Terraform's own
plan/apply cycle had produced a false sense of progress at least once.
**What I'd reconsider if:** a private endpoint is ever wired through the private-endpoints subnet
for this storage account specifically — at that point, reverting to
`public_network_access_enabled = false` would be the correct, fully-hardened state, with Terraform
itself running through the private path instead.
---
 
## Automated Testing — First Terratest Test
 
### [Testing] Bug: Pointing Terratest directly at a module folder fails with a missing provider configuration
 
**Date:** 2026-09-20
**Symptom:** `go test` compiled and ran, but `terraform apply` failed inside the test with
"Provider 'azurerm' requires explicit configuration... the argument 'features' is required, but
no definition was found" — despite `modules/networking/main.tf` never needing a provider block
in any other context in this project.
**Root cause:** `TerraformDir` was pointed directly at `../modules/networking`, treating the
module folder as if it were a standalone root config. But modules deliberately never configure
their own provider (the same rule established back in Phase 1, so a module's own provider
requirements don't conflict with whatever calls it) — they rely on the root config that calls
them to supply that configuration. Every previous successful `apply` of this module, in scratch
harnesses and in `examples/integration/`, worked precisely because it was always called from a
root config with its own `provider "azurerm" { features {} }` block. Terratest needs the exact
same thing; pointing it straight at a bare module skips that entirely.
**Fix:** Created `test/fixtures/networking/main.tf` — a small, dedicated root config (provider
block, a resource group, a `module "networking"` call, and an `output` re-exposing
`aks_subnet_id`) that Terratest actually runs against, instead of pointing at the module directly.
**Lesson:** The same "modules need a caller" rule that governed every manual test all project
applies identically to automated tests — Terratest doesn't get a special exception, and a module
folder is never a valid, standalone thing to `apply` on its own, regardless of which tool is
doing the applying.
 
---
 
### [Testing] Bug: Go map literal syntax error after removing an unused key
 
**Date:** 2026-09-20
**Symptom:** `go test` failed to even build, with `missing key in map literal` at the `Vars:`
field of `terraform.Options`.
**Root cause:** After moving `resource_group_name` into the new test fixture (removing the need
to pass it in as a variable), the key (`"resource_group_name":`) was deleted from the `Vars` map
literal but its value (the literal resource group name string) was left behind on its own line —
a Go map entry requires a `key: value` pair, and a bare value with no key doesn't compile.
**Fix:** Removed the `Vars` field from `terraform.Options` entirely, since the fixture now
creates its own resource group internally and needs no external input.
**Lesson:** A compile-time error in Go (caught before any Terraform command even runs) is a
different class of problem than a runtime Terraform error — worth recognizing the difference
quickly, since the fix is almost always a small, local syntax issue rather than anything to do
with Azure, providers, or infrastructure state.
 
---
 
<!-- New entries go below this line, in chronological order -->

 