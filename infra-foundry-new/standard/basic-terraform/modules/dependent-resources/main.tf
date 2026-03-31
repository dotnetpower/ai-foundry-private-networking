# =============================================================================
# Dependent Resources Module - Storage, Cosmos DB, AI Search
# =============================================================================

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "short_suffix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

# =============================================================================
# Storage Account
# =============================================================================

resource "azurerm_storage_account" "main" {
  name                          = "st${var.short_suffix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "ZRS"
  account_kind                  = "StorageV2"
  access_tier                   = "Hot"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled     = false  # Force Azure AD authentication (subscription policy)
  min_tls_version               = "TLS1_2"
  https_traffic_only_enabled    = true
  public_network_access_enabled = true   # Must be Enabled during deployment; disable after PE setup via CLI
  tags                          = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_container" "agents_data" {
  name                  = "agents-data"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "rag_documents" {
  name                  = "rag-documents"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "rag_chunks" {
  name                  = "rag-chunks"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# =============================================================================
# Azure Cosmos DB
# =============================================================================

resource "azurerm_cosmosdb_account" "main" {
  name                          = "cosmos-${var.short_suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  public_network_access_enabled = false
  network_acl_bypass_for_azure_services = true
  local_authentication_disabled = true
  tags                          = var.tags

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = false
  }
}

resource "azurerm_cosmosdb_sql_database" "agentdb" {
  name                = "agentdb"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "threads" {
  name                = "threads"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.agentdb.name

  partition_key_paths = ["/threadId"]
}

# =============================================================================
# Azure AI Search
# =============================================================================

resource "azurerm_search_service" "main" {
  name                          = "srch-${var.short_suffix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "standard"
  replica_count                 = 1
  partition_count               = 1
  hosting_mode                  = "default"
  public_network_access_enabled = false
  semantic_search_sku           = "standard"
  local_authentication_enabled  = true
  tags                          = var.tags

  authentication_failure_mode = "http401WithBearerChallenge"
}

# =============================================================================
# Outputs
# =============================================================================

output "storage_account_id" {
  value = azurerm_storage_account.main.id
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "cosmos_account_id" {
  value = azurerm_cosmosdb_account.main.id
}

output "cosmos_account_name" {
  value = azurerm_cosmosdb_account.main.name
}

output "cosmos_database_name" {
  value = azurerm_cosmosdb_sql_database.agentdb.name
}

output "search_service_id" {
  value = azurerm_search_service.main.id
}

output "search_service_name" {
  value = azurerm_search_service.main.name
}
