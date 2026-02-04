# =============================================================================
# Private Endpoints 및 DNS Zones
# =============================================================================

# -----------------------------------------------------------------------------
# Private DNS Zones
# -----------------------------------------------------------------------------

# AI Services / Cognitive Services DNS Zones
resource "azurerm_private_dns_zone" "cognitiveservices" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "openai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "services_ai" {
  name                = "privatelink.services.ai.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Storage DNS Zone
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# CosmosDB DNS Zone
resource "azurerm_private_dns_zone" "documents" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# AI Search DNS Zone
resource "azurerm_private_dns_zone" "search" {
  name                = "privatelink.search.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# DNS Zone VNet Links
# -----------------------------------------------------------------------------

resource "azurerm_private_dns_zone_virtual_network_link" "cognitiveservices" {
  name                  = "link-cognitiveservices"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cognitiveservices.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai" {
  name                  = "link-openai"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.openai.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "services_ai" {
  name                  = "link-services-ai"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.services_ai.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "link-blob"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "documents" {
  name                  = "link-documents"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.documents.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "search" {
  name                  = "link-search"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.search.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# -----------------------------------------------------------------------------
# Private Endpoints
# -----------------------------------------------------------------------------

# Storage Private Endpoint
resource "azurerm_private_endpoint" "storage" {
  name                = "pe-storage-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-storage"
    private_connection_resource_id = var.storage_account_id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "pdnsz-group-storage"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# CosmosDB Private Endpoint
resource "azurerm_private_endpoint" "cosmosdb" {
  name                = "pe-cosmosdb-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-cosmosdb"
    private_connection_resource_id = var.cosmos_db_id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "pdnsz-group-cosmosdb"
    private_dns_zone_ids = [azurerm_private_dns_zone.documents.id]
  }
}

# AI Search Private Endpoint
resource "azurerm_private_endpoint" "search" {
  name                = "pe-search-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-search"
    private_connection_resource_id = var.ai_search_id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "pdnsz-group-search"
    private_dns_zone_ids = [azurerm_private_dns_zone.search.id]
  }
}
