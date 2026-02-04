# ============================================================================
# Outputs for Azure AI Foundry Private Network Agent Setup
# ============================================================================

# ----------------------------------------------------------------------------
# Resource Group
# ----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

# ----------------------------------------------------------------------------
# Networking
# ----------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = module.networking.vnet_name
}

output "agent_subnet_id" {
  description = "ID of the Agent subnet"
  value       = module.networking.agent_subnet_id
}

output "pe_subnet_id" {
  description = "ID of the Private Endpoint subnet"
  value       = module.networking.pe_subnet_id
}

# ----------------------------------------------------------------------------
# AI Services
# ----------------------------------------------------------------------------

output "ai_account_name" {
  description = "Name of the AI Services account"
  value       = local.account_name
}

output "ai_account_id" {
  description = "ID of the AI Services account"
  value       = module.ai_services.account_id
}

output "ai_account_endpoint" {
  description = "Endpoint of the AI Services account"
  value       = module.ai_services.account_endpoint
}

# ----------------------------------------------------------------------------
# AI Project
# ----------------------------------------------------------------------------

output "project_name" {
  description = "Name of the AI Project"
  value       = local.project_name
}

output "project_id" {
  description = "ID of the AI Project"
  value       = module.project.project_id
}

output "project_workspace_id" {
  description = "Workspace ID of the AI Project"
  value       = module.project.project_workspace_id
}

output "capability_host_name" {
  description = "Name of the project capability host"
  value       = module.project.capability_host_name
}

# ----------------------------------------------------------------------------
# Dependencies
# ----------------------------------------------------------------------------

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = local.storage_name
}

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = module.dependencies.storage_id
}

output "cosmos_db_name" {
  description = "Name of the Cosmos DB account"
  value       = local.cosmos_db_name
}

output "cosmos_db_id" {
  description = "ID of the Cosmos DB account"
  value       = module.dependencies.cosmos_db_id
}

output "ai_search_name" {
  description = "Name of the AI Search service"
  value       = local.ai_search_name
}

output "ai_search_id" {
  description = "ID of the AI Search service"
  value       = module.dependencies.ai_search_id
}

# ----------------------------------------------------------------------------
# Connection Strings (for application use)
# ----------------------------------------------------------------------------

output "connections" {
  description = "Connection names for the AI Project"
  value = {
    cosmos_db = local.cosmos_db_name
    storage   = local.storage_name
    ai_search = local.ai_search_name
  }
}
