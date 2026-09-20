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

resource "azurerm_resource_group" "test" {
  name     = "rg-terratest-networking"
  location = "eastus"
}

module "networking" {
  source = "../../../modules/networking"

  resource_group_name = azurerm_resource_group.test.name
}

output "aks_subnet_id" {
  value = module.networking.aks_subnet_id
}