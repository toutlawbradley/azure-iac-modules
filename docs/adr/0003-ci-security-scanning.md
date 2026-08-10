# ADR-0003: CI Security Scanning — Trivy and GuardLine

**Status:** Accepted
**Date:** 2026-08-06

## Context

Phase 0's CI pipeline needed a security-scanning layer beyond basic syntax/lint checks
(`terraform fmt`, `terraform validate`, `tflint`), consistent with this project's predecessor
(GuardLine), which established CI-before-features as a working discipline. The realistic
open-source options for scanning Terraform for misconfigurations are Checkov and Trivy; tfsec
was ruled out as a new adoption since it has been deprecated and merged into Trivy. Separately,
GuardLine (an existing, shipped project) already performs secrets detection, dependency
vulnerability checks, config auditing, and code-pattern checks on a codebase — raising the
question of whether and how it fits alongside a dedicated IaC scanner in this project's pipeline.

## Decision

Use Trivy for scanning Terraform configuration for infrastructure misconfigurations. Retain
GuardLine in the pipeline, scoped specifically to the CI/CD pipeline definitions
(`.github/workflows/*.yml`) and any Dockerfiles introduced later (e.g., in Phase 3's integration
example) — a different target than Trivy, not a duplicate of it.

Checkov and Trivy are close on Terraform-specific rule coverage; Checkov has a larger raw rule
count, but Trivy's coverage is sufficient for this project's needs. The deciding factor was
Trivy's additional container/image scanning capability, unified in the same tool. Since AKS is
already in scope (Module 2) and container image scanning will be a real, near-term need once
workloads run on it, adopting Trivy now means that skill is learned as an extension of a tool
already in use, rather than requiring a second tool picked up cold in a later phase. Cost was not
a differentiator — both tools are free and open source.

GuardLine's own scan categories (notably secrets detection and configuration-risk auditing) would
substantially overlap with Trivy's and Checkov's built-in checks if pointed at the same Terraform
files — running both against the same target would be redundant, not complementary. Pointed
instead at the pipeline definitions themselves, GuardLine covers ground neither Trivy nor Checkov
is built to address: whether the pipeline that deploys the infrastructure is itself configured
safely (e.g., overly permissive `permissions:` blocks, secrets leaking into logs). This is a
real, non-redundant division of labor: Trivy audits what the pipeline deploys; GuardLine audits
the pipeline itself.

## Alternatives considered

- **Checkov** — broader rule library, more mature Terraform-specific coverage, native SARIF
  integration with GitHub's Security tab (also available in Trivy). Rejected in favor of Trivy
  primarily for the container-scanning compounding value given AKS is already in scope, not
  because Checkov is a worse tool.
- **Running GuardLine directly against the Terraform files, alongside Trivy** — rejected due to
  significant overlap in secrets-detection and config-auditing categories, which would weaken
  rather than strengthen the case for using both tools.

## Consequences

- CI pipeline runs two distinct scanners (Trivy, GuardLine) against two distinct targets
  (infrastructure code, pipeline definitions), both publishing findings to GitHub's Security tab.
- GuardLine may need modification later to handle Terraform/HCL directly if its scope expands —
  noted as an open, deferred decision, not part of this ADR.
- Establishes a reusable pattern (Trivy for container images) ahead of AKS workloads actually
  running, rather than needing to adopt a scanner under time pressure in Phase 2.