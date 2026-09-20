terraform {
  required_version = ">= 1.5.0"

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
  name     = "rg-iacmods-tfstate-dev-eus-001"
  location = "eastus"
}

resource "azurerm_storage_account" "main" {
  name                          = "stiacmodstfsdeveus001"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = "eastus"
  account_tier                  = "Standard"
  public_network_access_enabled = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  infrastructure_encryption_enabled = true
  account_replication_type          = "GRS"
}

resource "azurerm_storage_container" "main" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
