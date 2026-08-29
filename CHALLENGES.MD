# ADR-0001: Terraform vs. Bicep

**Status:** Accepted
**Date:** 2026-08-04

## Context

This project needs a single IaC tool to build four Azure modules (networking, AKS, storage,
Key Vault). Two realistic options exist: Terraform (multi-cloud, HashiCorp) and Bicep
(Azure-native, Microsoft). The tool needed to be chosen before any module code was written,
since state management and CI tooling both depend on the choice.

The two options trade off along the same axis: Bicep is Azure-only but tracks tightly with
AZ-104 material and gets same-day support for new Azure services; Terraform is broader
(multi-cloud), carries more operational complexity (a state file and backend to manage), and
is the higher-volume skill in general DevOps/cloud hiring.

## Decision

Use Terraform.

The deciding factor wasn't Terraform being "better" in the abstract — Bicep is a legitimate,
lower-overhead choice for an Azure-only project. It was fit with the broader learning roadmap:
Security+ → AZ-104 → HashiCorp Terraform Associate certification → deeper Kubernetes work
(AKS in this project, then a GitOps/IDP project after). Since Terraform sits deliberately after
AZ-104 in that roadmap, this project doubles as hands-on Terraform practice for that
certification — the module-building work and the exam prep reinforce each other instead of
being two separate learning efforts.

Terraform's state-file model was also better understood as a result of working through *why*
it exists: because Terraform supports many providers with incompatible native formats for
describing "what exists," it keeps its own translated, consistent record (state) rather than
querying each provider's native format directly, the way Bicep can afford to do since it only
ever talks to Azure/ARM. That operational overhead (a state backend, locking, a bootstrap step)
is a real cost, but one worth taking on given the roadmap fit.

Market data reviewed at decision time showed Terraform as the higher-volume skill overall
in DevOps/cloud hiring, while Bicep remains the tighter fit specifically for Azure-only shops
and is explicitly named in Azure-heavy postings. Neither is disqualifying; Terraform was judged
the better fit given the roadmap already pointed toward a HashiCorp certification.

## Alternatives considered

- **Bicep** — better AZ-104 alignment, lower operational overhead (no state file to manage),
  officially backed by Microsoft with faster support for new Azure service features. Rejected
  primarily because it doesn't compound with the Terraform-certification step already planned
  in the broader roadmap, and because Terraform has higher overall hiring volume outside of
  Azure-only shops specifically.

## Consequences

- Requires setting up and understanding state management (remote backend, locking, a one-time
  bootstrap step) before Phase 1 can begin — see the state backend ADR/log entry.
- HCL becomes the language for all four modules; module structure (`main.tf`/`variables.tf`/
  `outputs.tf` per module) follows Terraform convention rather than Bicep's file structure.
- Keeps the option open to apply the same tool to non-Azure providers later, though this
  project itself remains Azure-only in practice.
- Sets up direct, low-extra-effort preparation for the HashiCorp Terraform Associate exam once
  the four modules are built.