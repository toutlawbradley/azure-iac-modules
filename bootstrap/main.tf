terraform {
    required_providers{
        azurerm = {
            source  = "hashicorp/azurerm"
            version = "~>4.0"
        }
    }
}

provider "azurerm" {
    features{}
}

resource "azurerm_resource_group" "main" {
    name     = "rg-iacmods-tfstate-dev-eus-001"
    location = "eastus"
}

resource "azurerm_storage_account" "main" {
  name                          = "stiacmodstfsdeveus001"
  resource_group_name           =  azurerm_resource_group.main.name
  location                      = "eastus"
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
}

resource "azurerm_storage_container" "main" {
    name                   = "tfstate"
    storage_account_id   =  azurerm_storage_account.main.id
    container_access_type  = "private"
}

