terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-iacmods-dev-eus2-001"
  location            = "eastus2"
  resource_group_name = var.resource_group_name
  dns_prefix          = "iacmods-dev"

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    network_policy = "azure"
  }

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2s_v7"
    vnet_subnet_id = var.vnet_subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-iacmods-dev-eus2-001"
  location            = "eastus2"
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}