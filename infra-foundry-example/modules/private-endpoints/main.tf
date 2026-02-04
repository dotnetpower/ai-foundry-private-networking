# ============================================================================
# Private Endpoints Module - Private Endpoints and DNS Zones
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
# Private DNS Zones
# ============================================================================

resource "azurerm_private_dns_zone" "ai_services" {
  name                = var.dns_zone_names.ai_services
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "openai" {
  name                = var.dns_zone_names.openai
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "cognitive_services" {
  name                = var.dns_zone_names.cognitive_services
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "search" {
  name                = var.dns_zone_names.search
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = var.dns_zone_names.blob
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "cosmos_db" {
  name                = var.dns_zone_names.cosmos_db
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ============================================================================
# VNet Links for DNS Zones
# ============================================================================

resource "azurerm_private_dns_zone_virtual_network_link" "ai_services" {
  name                  = "aiServices-${var.suffix}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ai_services.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai" {
  name                  = "aiServicesOpenAI-${var.suffix}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.openai.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitive_services" {
  name                  = "aiServicesCognitiveServices-${var.suffix}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cognitive_services.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "search" {
  name                  = "aiSearch-${var.suffix}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.search.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "storage-${var.suffix}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_db" {
  name                  = "cosmosDB-${var.suffix}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos_db.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# ============================================================================
# Private Endpoint - AI Services Account
# ============================================================================

resource "azurerm_private_endpoint" "ai_account" {
  name                = "${var.ai_account_name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.ai_account_name}-private-link-service-connection"
    private_connection_resource_id = var.ai_account_id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name = "${var.ai_account_name}-dns-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.ai_services.id,
      azurerm_private_dns_zone.openai.id,
      azurerm_private_dns_zone.cognitive_services.id,
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.ai_services,
    azurerm_private_dns_zone_virtual_network_link.openai,
    azurerm_private_dns_zone_virtual_network_link.cognitive_services,
  ]
}

# ============================================================================
# Private Endpoint - AI Search
# ============================================================================

resource "azurerm_private_endpoint" "ai_search" {
  name                = "${var.ai_search_name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.ai_search_name}-private-link-service-connection"
    private_connection_resource_id = var.ai_search_id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name = "${var.ai_search_name}-dns-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.search.id,
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.search,
  ]
}

# ============================================================================
# Private Endpoint - Storage Account (Blob)
# ============================================================================

resource "azurerm_private_endpoint" "storage" {
  name                = "${var.storage_name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.storage_name}-private-link-service-connection"
    private_connection_resource_id = var.storage_id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name = "${var.storage_name}-dns-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.blob.id,
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.blob,
  ]
}

# ============================================================================
# Private Endpoint - Cosmos DB
# ============================================================================

resource "azurerm_private_endpoint" "cosmos_db" {
  name                = "${var.cosmos_db_name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.cosmos_db_name}-private-link-service-connection"
    private_connection_resource_id = var.cosmos_db_id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name = "${var.cosmos_db_name}-dns-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.cosmos_db.id,
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.cosmos_db,
  ]
}
