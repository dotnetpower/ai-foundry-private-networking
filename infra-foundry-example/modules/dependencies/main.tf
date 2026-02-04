# ============================================================================
# Dependencies Module - Storage, Cosmos DB, AI Search
# ============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  # CosmosDB doesn't support canary regions, fallback to westus
  canary_regions  = ["eastus2euap", "centraluseuap"]
  cosmos_location = contains(local.canary_regions, var.location) ? "westus" : var.location

  # No ZRS regions - use GRS instead
  no_zrs_regions = ["southindia", "westus"]
  storage_sku    = contains(local.no_zrs_regions, var.location) ? "Standard_GRS" : "Standard_ZRS"
}

# ============================================================================
# Storage Account
# ============================================================================

resource "azurerm_storage_account" "main" {
  name                            = var.storage_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = replace(local.storage_sku, "Standard_", "")
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  shared_access_key_enabled       = false

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = []
  }

  tags = var.tags
}

# ============================================================================
# Cosmos DB Account
# ============================================================================

resource "azurerm_cosmosdb_account" "main" {
  name                          = var.cosmos_db_name
  resource_group_name           = var.resource_group_name
  location                      = local.cosmos_location
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  public_network_access_enabled = false
  local_authentication_disabled = true
  automatic_failover_enabled    = false
  free_tier_enabled             = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = false
  }

  tags = var.tags
}

# ============================================================================
# AI Search Service
# ============================================================================

resource "azurerm_search_service" "main" {
  name                          = var.ai_search_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "standard"
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = false
  local_authentication_enabled  = false
  hosting_mode                  = "default"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
