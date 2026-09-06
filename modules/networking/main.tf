resource "azurerm_virtual_network" "main" {
    name                = "vnet-iacmods-dev-eus-001"
    resource_group_name = var.resource_group_name
    location            = "eastus"
    address_space       = ["10.0.0.0/16"]
}

