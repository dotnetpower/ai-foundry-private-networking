# ============================================================================
# Project Module - Outputs
# ============================================================================

output "project_id" {
  description = "ID of the AI Project"
  value       = azapi_resource.project.id
}

output "project_name" {
  description = "Name of the AI Project"
  value       = azapi_resource.project.name
}

output "project_principal_id" {
  description = "Principal ID of the AI Project (for RBAC)"
  value       = jsondecode(azapi_resource.project.output).identity.principalId
}

output "project_workspace_id" {
  description = "Workspace ID of the AI Project (formatted as GUID)"
  value       = local.workspace_id_guid
}

output "capability_host_id" {
  description = "ID of the Capability Host"
  value       = azapi_resource.capability_host.id
}

output "capability_host_name" {
  description = "Name of the Capability Host"
  value       = azapi_resource.capability_host.name
}

output "connections" {
  description = "Connection names"
  value = {
    cosmos_db = azapi_resource.connection_cosmos_db.name
    storage   = azapi_resource.connection_storage.name
    ai_search = azapi_resource.connection_ai_search.name
  }
}
