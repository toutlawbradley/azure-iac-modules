# Challenges & Decisions Log — Azure IaC Module Library

Real bugs, real decisions, real reasoning — logged as they happen, not reconstructed afterward.
Same discipline as GuardLine's log: if it took more than 10 minutes to figure out, or if there
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

Log entries in the order they happen.

---

## Phase 0 — Foundation

### [Phase 0] Decision: Terraform vs. Bicep

**Date:** 2026-08-03
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

**Date:** 2026-08-03
**Options considered:** Local state, remote state (Azure Storage backend with locking)
**Chose:** Remote state (Azure Storage), bootstrapped via a small, separate Terraform config in
`bootstrap/` that intentionally uses local state
**Why:** _(fill in: durability — a local state file dying with your laptop means Terraform loses
track of everything it manages — and locking, which prevents two concurrent applies, e.g. you
locally plus CI, from corrupting the state. Also: why the bootstrap step itself is the one
legitimate place local state is fine.)*
**What I'd reconsider if:** _(fill in)*

---

### [Phase 0] Decision: CI security scanning — Trivy vs. Checkov, and GuardLine's role

**Date:** 2026-08-09
**Options considered:** Checkov, Trivy (tfsec ruled out — deprecated, merged into Trivy)
**Chose:** Trivy for Terraform/infrastructure scanning; GuardLine (existing project) retained for
scanning CI/CD pipeline config (`.github/workflows/*.yml`) and any future Dockerfiles — a
different layer than Trivy, not a duplicate of it
**Why:** _(fill in: the AKS-alignment reasoning — Trivy also covers container image scanning,
which the AKS module will eventually need — and the GuardLine division of labor: Trivy audits
what the pipeline deploys, GuardLine audits the pipeline itself.)*
**What I'd reconsider if:** _(fill in)*

---

### [Phase 0] Decision: Resource naming convention

**Date:** 2026-08-09
**Options considered:** Ad-hoc naming, Microsoft Cloud Adoption Framework (CAF) pattern
**Chose:** CAF pattern — `{type}-{workload}-{environment}-{region}-{instance}`,
e.g. `rg-iacmods-dev-eus-001`. Key Vault uses a Terraform `random` provider suffix instead of a
fixed instance number.
**Why:** _(fill in: alignment with AZ-104 material, and the Key Vault exception — 24-character
limit + global uniqueness requirement made a fixed instance number insufficient.)*
**What I'd reconsider if:** _(fill in)*

---

<!-- New entries go below this line, in chronological order -->