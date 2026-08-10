# ADR-0002: Remote State Backend (Azure Storage)

**Status:** Accepted
**Date:** 2026-08-09

## Context

Terraform needs a location to store its state file — the record it uses to compare declared
configuration against what it believes already exists. This location must be decided before
Phase 1 (the first real module) begins, since every subsequent module's configuration depends on
where state lives. Two options exist: local state (a file on whichever machine runs
`terraform apply`) or a remote backend (for Azure, an Azure Storage Account with a blob
container).

## Decision

Use a remote Azure Storage backend for all real modules (`modules/`, `examples/integration/`).
Bootstrap the storage account itself using a small, separate Terraform configuration in
`bootstrap/` that intentionally uses local state, since nothing exists yet for that first apply
to point at.

Local state carries two risks that don't surface until they occur: durability (loss of the
machine holding the file means Terraform loses all record of what it manages, with no clean
recovery path short of manual reconciliation or a full rebuild) and concurrency (no protection
against two simultaneous `terraform apply` runs corrupting the same state file). A remote Azure
Storage backend addresses both — Azure durably stores and replicates the blob, and the backend
supports lease-based locking, rejecting a second apply while one is in progress.

Since this project has CI validation from Phase 0 onward, there are at least two potential
appliers from day one (a local run, and eventually CI), which rules out local state as a
realistic choice for the real modules regardless of team size.

## Alternatives considered

- **Local state for everything** — simplest to set up, no backend configuration needed. Rejected
  because the durability and concurrency risks apply even to a solo developer once CI is in the
  picture, and because remote state with locking is the standard, expected pattern for any
  project meant to look and function professionally.

## Consequences

- Requires a one-time manual bootstrap step (`bootstrap/`) before any other module can be
  applied, since the backend itself can't be created by the thing that depends on it existing.
- The `bootstrap/` folder's local state file must be excluded from version control
  (`.gitignore`: `*.tfstate`, `*.tfstate.backup`, `.terraform/`) — this is the one place in the
  repo where local state is an intentional exception, not an oversight.
- All other modules' `backend.tf` configuration must reference the bootstrapped storage account,
  container, and resource group by name.