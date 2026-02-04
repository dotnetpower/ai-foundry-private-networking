# ============================================================================
# Private Endpoints Module - Outputs
# ============================================================================

# Private DNS Zones
output "dns_zone_ai_services_id" {
  description = "ID of the AI Services DNS Zone"
  value       = azurerm_private_dns_zone.ai_services.id
}

output "dns_zone_openai_id" {
  description = "ID of the OpenAI DNS Zone"
  value       = azurerm_private_dns_zone.openai.id
}

output "dns_zone_cognitive_services_id" {
  description = "ID of the Cognitive Services DNS Zone"
  value       = azurerm_private_dns_zone.cognitive_services.id
}

output "dns_zone_search_id" {
  description = "ID of the Search DNS Zone"
  value       = azurerm_private_dns_zone.search.id
}

output "dns_zone_blob_id" {
  description = "ID of the Blob DNS Zone"
  value       = azurerm_private_dns_zone.blob.id
}

output "dns_zone_cosmos_db_id" {
  description = "ID of the Cosmos DB DNS Zone"
  value       = azurerm_private_dns_zone.cosmos_db.id
}

# Private Endpoints
output "pe_ai_account_id" {
  description = "ID of the AI Account Private Endpoint"
  value       = azurerm_private_endpoint.ai_account.id
}

output "pe_ai_search_id" {
  description = "ID of the AI Search Private Endpoint"
  value       = azurerm_private_endpoint.ai_search.id
}

output "pe_storage_id" {
  description = "ID of the Storage Private Endpoint"
  value       = azurerm_private_endpoint.storage.id
}

output "pe_cosmos_db_id" {
  description = "ID of the Cosmos DB Private Endpoint"
  value       = azurerm_private_endpoint.cosmos_db.id
}
