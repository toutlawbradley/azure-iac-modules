resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-iacmods-dev-eus-001"
  location            = "eastus2"
  resource_group_name = var.resource_group_name
  dns_prefix          = "iacmods-dev"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2s_v7"
    vnet_subnet_id = var.vnet_subnet_id
  }

  identity {
    type = "SystemAssigned"
  }
}