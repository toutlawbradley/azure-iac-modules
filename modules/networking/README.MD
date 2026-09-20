# Networking Module

Foundation module for the project: a Virtual Network with two subnets and per-subnet Network
Security Groups. Every other module (AKS, database, Key Vault) depends on this one for its
network placement.

## What this creates

- One `azurerm_virtual_network`, address space `10.0.0.0/16`
- Two subnets:
  - `snet-aks-*` (`10.0.1.0/24`) — for AKS node pools (compute, needs broader inbound access)
  - `snet-pe-*` (`10.0.2.0/24`) — for private endpoints fronting storage/Key Vault (internal-only)
- Two Network Security Groups, one per subnet, each with rules scoped to what that subnet
  actually needs — not a single shared rule set. See the root project's `CHALLENGES.md` and
  `docs/adr/` for the reasoning behind the subnet split and the specific rule choices (notably,
  why port 80 is allowed rather than denied, and why the AKS NSG intentionally allows ingress
  from any source while the private-endpoints NSG is scoped to the AKS subnet specifically).

## Inputs

| Name | Type | Description |
|---|---|---|
| `resource_group_name` | `string` | Name of the resource group where these resources will be created. Not created by this module — expected to already exist or be created by the caller. |

## Outputs

| Name | Description |
|---|---|
| `vnet_id` | ID of the virtual network, for any future module that needs to reference the VNet itself (peering, DNS, etc.) |
| `aks_subnet_id` | ID of the AKS subnet — consumed by the `aks` module's `vnet_subnet_id` input |
| `private_endpoints_subnet_id` | ID of the private-endpoints subnet — for the storage/Key Vault private endpoints (not yet wired) |

## Example usage

```hcl
module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
}
```