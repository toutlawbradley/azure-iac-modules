# ADR-0004: Resource Naming Convention (Cloud Adoption Framework)

**Status:** Accepted
**Date:** 2026-08-06

## Context

Every resource created by these modules needs a consistent, predictable name. Azure imposes
hard platform constraints on some resource types (e.g., Key Vault: 24-character limit, globally
unique across all of Azure, letters/numbers/hyphens only) that any naming scheme must respect.
A naming decision was needed before Phase 1, since it affects every module's variable defaults.

## Decision

Follow Microsoft's Cloud Adoption Framework (CAF) naming pattern:
`{type}-{workload}-{environment}-{region}-{instance}`, e.g. `rg-iacmods-dev-eus-001`, using
Microsoft's standard resource-type abbreviations (`rg`, `vnet`, `nsg`, `aks`, `kv`, `st`, etc.).

CAF is Microsoft's own recommended standard and is reflected directly in AZ-104 material, so
using it reinforces concurrent cert study — consistent with this project's broader goal of
letting the cert and the hands-on work reinforce each other. It also communicates real
information about a resource (type, purpose, environment, region) at a glance, rather than an
arbitrary name.

Key Vault required a deviation from the plain `{instance}` slot: Azure's 24-character limit and
global-uniqueness requirement mean a fixed, guessable number like `-001` doesn't solve the real
constraint (uniqueness) — only length. Key Vault names in this project instead use a
Terraform-generated random suffix (via the `random` provider) in place of the fixed instance
number. The generated value is persisted in Terraform state so it remains stable across
subsequent applies rather than regenerating (and changing the resource's identity) each time.

## Alternatives considered

- **Ad-hoc naming** — faster to start with, but provides no consistent signal about a resource's
  type, environment, or purpose, and doesn't reinforce AZ-104 study. Rejected.
- **Fixed instance number for Key Vault (matching all other resources)** — rejected once the
  24-character limit and global-uniqueness constraint were confirmed; a fixed number is
  insufficient to guarantee uniqueness across all of Azure.
- **Manually-chosen unique suffix for Key Vault (e.g., initials)** — considered as an alternative
  to a random suffix; rejected in favor of an automatically generated value to remove the need
  for manual coordination, especially if additional environments or instances are added later.

## Consequences

- Every module's default naming logic follows the same five-part pattern, except Key Vault's
  instance slot.
- Key Vault's module needs a `random_string` (or `random_id`) resource wired in specifically to
  generate and persist the uniqueness suffix.
- Any future resource type added to this project should have its CAF abbreviation looked up
  (Microsoft publishes an official list) before being named, to keep the convention consistent.