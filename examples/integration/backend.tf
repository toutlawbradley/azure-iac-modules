terraform {
  backend "azurerm" {
    resource_group_name  = "rg-iacmods-tfstate-dev-eus-001"
    storage_account_name = "stiacmodstfsdeveus001"
    container_name       = "tfstate"
    key                  = "integration.tfstate"
  }
}