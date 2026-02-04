# Storage Account
output "storage_account_id" {
  description = "Storage Account ID"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Storage Account 이름"
  value       = azurerm_storage_account.main.name
}

output "storage_blob_endpoint" {
  description = "Storage Blob 엔드포인트"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

# AI Search
output "ai_search_id" {
  description = "AI Search 서비스 ID"
  value       = azurerm_search_service.main.id
}

output "ai_search_name" {
  description = "AI Search 서비스 이름"
  value       = azurerm_search_service.main.name
}

output "ai_search_endpoint" {
  description = "AI Search 엔드포인트"
  value       = "https://${azurerm_search_service.main.name}.search.windows.net"
}

# CosmosDB
output "cosmos_db_id" {
  description = "CosmosDB 계정 ID"
  value       = azurerm_cosmosdb_account.main.id
}

output "cosmos_db_name" {
  description = "CosmosDB 계정 이름"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmos_db_endpoint" {
  description = "CosmosDB 문서 엔드포인트"
  value       = azurerm_cosmosdb_account.main.endpoint
}
