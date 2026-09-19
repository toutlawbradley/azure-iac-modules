terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_password" "sql_admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_mssql_server" "main" {
  name                          = "sql-iacmods-dev-eus-001"
  resource_group_name           = var.resource_group_name
  location                      = "eastus"
  version                       = "12.0"
  administrator_login           = "sqladmin"
  administrator_login_password  = random_password.sql_admin.result
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "main" {
  name      = "db-iacmods-dev-eus-001"
  server_id = azurerm_mssql_server.main.id
}