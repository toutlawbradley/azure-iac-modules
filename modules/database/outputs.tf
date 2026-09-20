output "sql_admin_password" {
  value     = random_password.sql_admin.result
  sensitive = true
}

output "db_id" {
  value = azurerm_mssql_database.main.id
}