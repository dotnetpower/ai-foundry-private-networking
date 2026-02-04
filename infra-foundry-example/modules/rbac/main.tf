# ============================================================================
# RBAC Module - Role Assignments for AI Project
# ============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
  }
}

data "azurerm_client_config" "current" {}

# ============================================================================
# Role Definitions
# ============================================================================

locals {
  # Built-in role definition IDs
  role_definitions = {
    storage_blob_data_contributor = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    storage_blob_data_owner       = "b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
    cosmos_db_operator            = "230815da-be43-4aae-9cb4-875f7bd000aa"
    search_index_data_contributor = "8ebe5a00-799e-43f5-93ac-243d3dce84a7"
    search_service_contributor    = "7ca78c08-252a-4471-8644-bb5ff32d4ba0"
    cosmos_db_data_contributor    = "00000000-0000-0000-0000-000000000002" # Cosmos DB Built-in Data Contributor
  }

  # Condition for Storage Blob Data Owner (agent-specific containers only)
  storage_condition = <<-EOT
    ((!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read'})  AND 
    !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action'}) AND 
    !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write'}) ) OR
    (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase 
    '${var.project_workspace_id}' AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] 
    StringLikeIgnoreCase '*-azureml-agent'))
  EOT
}

# ============================================================================
# Storage Account Role Assignments
# ============================================================================

# Storage Blob Data Contributor for Project
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = var.storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.project_principal_id
  principal_type       = "ServicePrincipal"
}

# Storage Blob Data Owner with Condition (for agent containers)
resource "azurerm_role_assignment" "storage_blob_data_owner" {
  scope                = var.storage_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.project_principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = local.storage_condition
}

# ============================================================================
# Cosmos DB Role Assignments
# ============================================================================

# Cosmos DB Operator
resource "azurerm_role_assignment" "cosmos_db_operator" {
  scope                = var.cosmos_db_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = var.project_principal_id
  principal_type       = "ServicePrincipal"
}

# Cosmos DB SQL Role Assignment (for data access)
resource "azapi_resource" "cosmos_db_data_contributor" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15"
  name      = uuidv5("dns", "${var.project_workspace_id}-${var.cosmos_db_name}-${local.role_definitions.cosmos_db_data_contributor}-${var.project_principal_id}")
  parent_id = var.cosmos_db_id

  body = {
    properties = {
      principalId      = var.project_principal_id
      roleDefinitionId = "${var.cosmos_db_id}/sqlRoleDefinitions/${local.role_definitions.cosmos_db_data_contributor}"
      scope            = "${var.cosmos_db_id}/dbs/enterprise_memory"
    }
  }
}

# ============================================================================
# AI Search Role Assignments
# ============================================================================

# Search Index Data Contributor
resource "azurerm_role_assignment" "search_index_data_contributor" {
  scope                = var.ai_search_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = var.project_principal_id
  principal_type       = "ServicePrincipal"
}

# Search Service Contributor
resource "azurerm_role_assignment" "search_service_contributor" {
  scope                = var.ai_search_id
  role_definition_name = "Search Service Contributor"
  principal_id         = var.project_principal_id
  principal_type       = "ServicePrincipal"
}
