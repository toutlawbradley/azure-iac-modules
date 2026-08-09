# Azure IaC Module Library

## Scope

This project builds four reusable Terraform modules for Azure: a resource group and networking
foundation (VNet, subnets, NSGs), an AKS cluster, a storage/database module, and a Key Vault
module. A Phase 3 integration example composes all four together into a real, deployed (and torn
down) environment. Scope is deliberately limited to these four modules — anything beyond this list
requires a real reason, written down, before it gets added.

## Why this project

- First hands-on infrastructure-as-code project, distinct from [GuardLine](#) (application/tooling
  security scanner, shipped).
- Runs in parallel with AZ-104 study — the cert study makes the modules more correct and idiomatic;
  building the modules makes the cert concepts concrete.
- Feeds directly into a later GitOps pipeline project, which will consume these modules.
- The Key Vault module is a deliberate callback to GuardLine's secrets-detection scanner: this is
  the pattern GuardLine tells people to use instead of hardcoding credentials.

## Tooling decisions

| Decision | Choice | Details |
|---|---|---|
| IaC tool | Terraform | See [`docs/adr/0001-terraform-vs-bicep.md`](docs/adr/0001-terraform-vs-bicep.md) |
| State backend | Azure Storage (remote, with locking) | Bootstrapped via a small, local-state-only config in `bootstrap/` — see that folder's README |
| CI validation | `terraform fmt`, `terraform validate`, `tflint` | Runs on every push/PR |
| IaC security scanning | [Trivy](https://github.com/aquasecurity/trivy) | Scans Terraform for infrastructure misconfigurations; findings published to GitHub's Security tab |
| Pipeline security scanning | [GuardLine](#) | Scans `.github/workflows/*.yml` (and any Dockerfiles introduced later) for pipeline-level misconfigurations — a different layer than Trivy, not a duplicate of it |
| Resource naming | Microsoft Cloud Adoption Framework pattern: `{type}-{workload}-{environment}-{region}-{instance}` | e.g. `rg-iacmods-dev-eus-001`. Key Vault uses a Terraform-generated random suffix instead of a fixed instance number, for global-uniqueness reasons — see `modules/key-vault/README.md` |

## Repo structure

```
azure-iac-modules/
├── bootstrap/              # One-time setup: creates the remote state storage account (local state, intentionally)
├── modules/
│   ├── networking/         # Resource group, VNet, subnets, NSGs
│   ├── aks/                # AKS cluster
│   ├── storage/            # Storage or database (final pick: TBD in Phase 2)
│   └── key-vault/          # Key Vault, RBAC/managed-identity access
├── examples/
│   └── integration/        # Phase 3: composes all four modules, real deploy + teardown
├── docs/
│   └── adr/                # Architecture Decision Records
├── .github/workflows/      # CI: validate, lint, Trivy, GuardLine
└── CHALLENGES.md           # Running log of real decisions and bugs
```

## Status

Phase 0 (foundation decisions) is complete. See `CHALLENGES.md` for the decision log and
`docs/adr/` for formal ADRs. Phase 1 (networking module) has not yet started.