# ============================================================================
# RBAC Module - Outputs
# ============================================================================

output "storage_blob_data_contributor_id" {
  description = "ID of the Storage Blob Data Contributor role assignment"
  value       = azurerm_role_assignment.storage_blob_data_contributor.id
}

output "storage_blob_data_owner_id" {
  description = "ID of the Storage Blob Data Owner role assignment"
  value       = azurerm_role_assignment.storage_blob_data_owner.id
}

output "cosmos_db_operator_id" {
  description = "ID of the Cosmos DB Operator role assignment"
  value       = azurerm_role_assignment.cosmos_db_operator.id
}

output "cosmos_db_data_contributor_id" {
  description = "ID of the Cosmos DB SQL Role assignment"
  value       = azapi_resource.cosmos_db_data_contributor.id
}

output "search_index_data_contributor_id" {
  description = "ID of the Search Index Data Contributor role assignment"
  value       = azurerm_role_assignment.search_index_data_contributor.id
}

output "search_service_contributor_id" {
  description = "ID of the Search Service Contributor role assignment"
  value       = azurerm_role_assignment.search_service_contributor.id
}
