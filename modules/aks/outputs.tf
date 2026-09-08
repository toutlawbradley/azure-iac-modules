output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "aks_principal_id" {
  value = azurerm_kubernetes_cluster.main.identity[0].principal_id
}