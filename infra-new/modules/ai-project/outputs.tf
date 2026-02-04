output "project_id" {
  description = "AI Project ID"
  value       = azapi_resource.ai_project.id
}

output "project_name" {
  description = "AI Project 이름"
  value       = azapi_resource.ai_project.name
}

output "project_principal_id" {
  description = "Project System Managed Identity Principal ID"
  value       = jsondecode(azapi_resource.ai_project.output).identity.principalId
}

output "project_internal_id" {
  description = "Project Internal ID (workspaceId)"
  value       = jsondecode(azapi_resource.ai_project.output).properties.internalId
}

# Connection 이름 출력 (Capability Host에서 사용)
output "cosmos_db_connection" {
  description = "CosmosDB Connection 이름"
  value       = azapi_resource.connection_cosmosdb.name
}

output "storage_connection" {
  description = "Storage Connection 이름"
  value       = azapi_resource.connection_storage.name
}

output "ai_search_connection" {
  description = "AI Search Connection 이름"
  value       = azapi_resource.connection_search.name
}
