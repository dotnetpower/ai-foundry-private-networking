# Private DNS Zone IDs
output "private_dns_zone_ids" {
  description = "Private DNS Zone ID 맵"
  value = {
    cognitiveservices = azurerm_private_dns_zone.cognitiveservices.id
    openai            = azurerm_private_dns_zone.openai.id
    services_ai       = azurerm_private_dns_zone.services_ai.id
    blob              = azurerm_private_dns_zone.blob.id
    documents         = azurerm_private_dns_zone.documents.id
    search            = azurerm_private_dns_zone.search.id
  }
}

# Private Endpoint IDs
output "storage_pe_id" {
  description = "Storage Private Endpoint ID"
  value       = azurerm_private_endpoint.storage.id
}

output "cosmosdb_pe_id" {
  description = "CosmosDB Private Endpoint ID"
  value       = azurerm_private_endpoint.cosmosdb.id
}

output "search_pe_id" {
  description = "AI Search Private Endpoint ID"
  value       = azurerm_private_endpoint.search.id
}
