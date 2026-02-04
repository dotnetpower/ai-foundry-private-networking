# ============================================================================
# Dependencies Module - Outputs
# ============================================================================

# Storage Account
output "storage_id" {
  description = "ID of the Storage Account"
  value       = azurerm_storage_account.main.id
}

output "storage_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.main.name
}

output "storage_blob_endpoint" {
  description = "Blob endpoint of the Storage Account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_file_endpoint" {
  description = "File endpoint of the Storage Account"
  value       = azurerm_storage_account.main.primary_file_endpoint
}

# Cosmos DB
output "cosmos_db_id" {
  description = "ID of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.id
}

output "cosmos_db_name" {
  description = "Name of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmos_db_endpoint" {
  description = "Document endpoint of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.endpoint
}

# AI Search
output "ai_search_id" {
  description = "ID of the AI Search service"
  value       = azurerm_search_service.main.id
}

output "ai_search_name" {
  description = "Name of the AI Search service"
  value       = azurerm_search_service.main.name
}

output "ai_search_endpoint" {
  description = "Endpoint of the AI Search service"
  value       = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "ai_search_principal_id" {
  description = "Principal ID of the AI Search service"
  value       = azurerm_search_service.main.identity[0].principal_id
}
