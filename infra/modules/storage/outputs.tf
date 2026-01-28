output "storage_account_id" {
  description = "Storage Account ID"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Storage Account 이름"
  value       = azurerm_storage_account.main.name
}

output "container_registry_id" {
  description = "Container Registry ID"
  value       = azurerm_container_registry.main.id
}

output "container_registry_name" {
  description = "Container Registry 이름"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Container Registry 로그인 서버"
  value       = azurerm_container_registry.main.login_server
}
