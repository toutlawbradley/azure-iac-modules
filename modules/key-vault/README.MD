# Key Vault Module

Stores the database module's generated secret and grants exactly one identity — the AKS
cluster's managed identity — narrow, read-only access to it via RBAC. This is the module the
rest of the project's secret-handling design points toward, and a direct callback to GuardLine's
secrets-detection thesis: this is the pattern GuardLine's findings tell people to use instead of
hardcoding credentials.

## What this creates

- One `azurerm_key_vault`, RBAC-authorization mode (`rbac_authorization_enabled = true`, not the
  older access-policy model), with purge protection and network ACLs (default deny) enabled
- One `azurerm_key_vault_secret` storing the database module's generated password, taken as a
  sensitive input rather than read directly (this module has no way to see into the database
  module's own resources — only what it's explicitly given)
- Two separate `azurerm_role_assignment` resources on the vault:
  - **Key Vault Secrets User**, granted to the AKS cluster's managed identity — read-only,
    nothing more
  - **Key Vault Secrets Officer**, granted to whichever identity runs Terraform — needed to
    write the secret in the first place, deliberately kept as a separate, broader-but-distinct
    grant rather than reusing the same role for both purposes (see `CHALLENGES.md` for the time
    this got collapsed into one role by mistake, and how it was caught and fixed)

## Inputs

| Name | Type | Description |
|---|---|---|
| `resource_group_name` | `string` | Name of the resource group where Key Vault resources will be created |
| `sql_admin_password` | `string` (sensitive) | The database module's generated password, intended to come from `module.database.sql_admin_password` |
| `aks_principal_id` | `string` | The AKS cluster's managed identity principal ID, intended to come from `module.aks.aks_principal_id` |

## Outputs

| Name | Description |
|---|---|
| `key_vault_id` | ID of the vault, for any future resource that needs to reference it |
| `key_vault_uri` | The vault's HTTPS endpoint — what a running application would use at runtime to actually fetch secrets |

## Known limitation

`public_network_access_enabled` is currently `true`. Locking this to `false` (the originally
intended, hardened setting) blocks Terraform's own data-plane write of the secret unless it runs
from inside the VNet or through a private endpoint — a real, common production tension, not a
bug. The networking module's private-endpoints subnet exists specifically to eventually support
this properly; wiring an actual private endpoint through it is deliberate future work.

## Example usage

```hcl
module "key_vault" {
  source = "../../modules/key-vault"

  resource_group_name = azurerm_resource_group.main.name
  sql_admin_password   = module.database.sql_admin_password
  aks_principal_id     = module.aks.aks_principal_id
}
```