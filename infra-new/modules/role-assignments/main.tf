# =============================================================================
# RBAC 역할 할당 (Capability Host 생성 전 필수!)
# =============================================================================

# -----------------------------------------------------------------------------
# Storage Account 역할 할당
# -----------------------------------------------------------------------------

# Storage Blob Data Contributor (Account 수준)
resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.project_principal_id
}

# Storage Blob Data Owner (Account 수준 - Container 생성 권한용)
resource "azurerm_role_assignment" "storage_blob_owner" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.project_principal_id
}

# Storage Queue Data Contributor (Azure Function Tool 지원용)
resource "azurerm_role_assignment" "storage_queue_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = var.project_principal_id
}

# -----------------------------------------------------------------------------
# CosmosDB 역할 할당
# -----------------------------------------------------------------------------

# Cosmos DB Operator (필수 - Capability Host 생성 전)
resource "azurerm_role_assignment" "cosmosdb_operator" {
  scope                = var.cosmos_db_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = var.project_principal_id
}

# Cosmos DB Account Reader
resource "azurerm_role_assignment" "cosmosdb_reader" {
  scope                = var.cosmos_db_id
  role_definition_name = "Cosmos DB Account Reader Role"
  principal_id         = var.project_principal_id
}

# Cosmos DB Built-in Data Contributor (SQL Role)
resource "azurerm_cosmosdb_sql_role_assignment" "data_contributor" {
  resource_group_name = var.resource_group_name
  account_name        = var.cosmos_db_name
  # Built-in Data Contributor Role ID
  role_definition_id = "${var.cosmos_db_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id       = var.project_principal_id
  scope              = var.cosmos_db_id
}

# -----------------------------------------------------------------------------
# AI Search 역할 할당
# -----------------------------------------------------------------------------

# Search Index Data Contributor
resource "azurerm_role_assignment" "search_index_contributor" {
  scope                = var.ai_search_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = var.project_principal_id
}

# Search Service Contributor
resource "azurerm_role_assignment" "search_service_contributor" {
  scope                = var.ai_search_id
  role_definition_name = "Search Service Contributor"
  principal_id         = var.project_principal_id
}

# 역할 전파 대기 (RBAC 전파에 시간 소요)
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.storage_blob_contributor,
    azurerm_role_assignment.storage_blob_owner,
    azurerm_role_assignment.storage_queue_contributor,
    azurerm_role_assignment.cosmosdb_operator,
    azurerm_cosmosdb_sql_role_assignment.data_contributor,
    azurerm_role_assignment.search_index_contributor,
    azurerm_role_assignment.search_service_contributor
  ]

  create_duration = "60s"
}
