# =============================================================================
# 의존 리소스 모듈 - CosmosDB, Storage, AI Search
# =============================================================================

# Storage Account (Agent File Storage)
resource "azurerm_storage_account" "main" {
  name                     = var.storage_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"

  # 보안 설정
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  shared_access_key_enabled       = false # AAD 인증만 사용

  # Blob 서비스 설정
  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

# AI Search Service (Vector Store)
resource "azurerm_search_service" "main" {
  name                          = var.ai_search_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.search_sku
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = false
  local_authentication_enabled  = var.search_sku == "free" ? true : false # free SKU는 AAD 미지원

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# CosmosDB Account (Thread Storage)
resource "azurerm_cosmosdb_account" "main" {
  name                          = var.cosmos_db_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  public_network_access_enabled = false
  local_authentication_disabled = true # AAD 인증만 사용

  # Session 일관성 (권장)
  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
