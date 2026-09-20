terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-iacmods-dev-eus2-001"
  location = "eastus2"
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
}

module "aks" {
  source = "../../modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  vnet_subnet_id       = module.networking.aks_subnet_id
}

module "database" {
  source = "../../modules/database"

  resource_group_name = azurerm_resource_group.main.name
}

module "key_vault" {
  source = "../../modules/key-vault"

  resource_group_name = azurerm_resource_group.main.name
  sql_admin_password   = module.database.sql_admin_password
  aks_principal_id     = module.aks.aks_principal_id
}