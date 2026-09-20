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
    ip_rules       = ["73.9.159.182"]
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

  account_replication_type          = "GRS"
}

resource "azurerm_storage_container" "main" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "terraform_blob_access" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}