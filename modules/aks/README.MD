# AKS Module

Provisions an Azure Kubernetes Service cluster, wired into the networking module's AKS subnet,
with a system-assigned managed identity for accessing other Azure resources (specifically, the
Key Vault module) without any manually managed credential.

## What this creates

- One `azurerm_kubernetes_cluster` with a single-node `default_node_pool`
- A `SystemAssigned` managed identity, giving the cluster its own Azure-recognized identity
  rather than relying on a shared or manually created service principal
- A `network_profile` with a service CIDR (`10.1.0.0/16`) deliberately non-overlapping with the
  VNet's own address space, and Azure's network policy enabled for pod-level network
  segmentation
- A dedicated Log Analytics Workspace, wired via `oms_agent`, for cluster logging

## Inputs

| Name | Type | Description |
|---|---|---|
| `resource_group_name` | `string` | Name of the resource group where the cluster will be created |
| `vnet_subnet_id` | `string` | ID of the subnet the node pool deploys into — intended to come from `module.networking.aks_subnet_id`, not a hardcoded value |

## Outputs

| Name | Description |
|---|---|
| `aks_cluster_id` | ID of the cluster, for anything that needs to reference it directly |
| `aks_principal_id` | The managed identity's principal ID — consumed by the `key-vault` module's `aks_principal_id` input, used to grant this identity a narrowly-scoped RBAC role on the vault |

## Known, deliberately deferred hardening

Documented in the project's `CHALLENGES.md` rather than left unexplained: API server authorized
IP ranges, private cluster mode, the Azure Policy add-on, and a dedicated disk encryption set are
all real Trivy-flagged findings that require meaningfully more infrastructure or operational
complexity (App Registrations, a bastion/VPN path to the API server, a policy assignment) than
this pass covered, and were deferred rather than half-implemented.

## Example usage

```hcl
module "aks" {
  source = "../../modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  vnet_subnet_id       = module.networking.aks_subnet_id
}
```