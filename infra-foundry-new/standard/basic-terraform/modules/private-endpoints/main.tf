# =============================================================================
# Private Endpoints Module - PE for Foundry, Storage, Cosmos DB, AI Search
# =============================================================================

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "foundry_account_id" {
  type = string
}

variable "storage_account_id" {
  type = string
}

variable "cosmos_account_id" {
  type = string
}

variable "search_service_id" {
  type = string
}

variable "private_dns_zone_ids" {
  type = map(string)
}

# =============================================================================
# Private Endpoint for Foundry Account
# =============================================================================

resource "azurerm_private_endpoint" "foundry" {
  name                = "pe-${var.name_prefix}-foundry"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "plsc-foundry"
    private_connection_resource_id = var.foundry_account_id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["cognitiveservices"],
      var.private_dns_zone_ids["openai"],
      var.private_dns_zone_ids["servicesai"],
    ]
  }
}

# =============================================================================
# Private Endpoint for Storage Account (Blob)
# =============================================================================

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-${var.name_prefix}-storage-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "plsc-storage-blob"
    private_connection_resource_id = var.storage_account_id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["blob"],
    ]
  }
}

# =============================================================================
# Private Endpoint for Storage Account (File)
# =============================================================================

resource "azurerm_private_endpoint" "storage_file" {
  name                = "pe-${var.name_prefix}-storage-file"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "plsc-storage-file"
    private_connection_resource_id = var.storage_account_id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["file"],
    ]
  }
}

# =============================================================================
# Private Endpoint for Cosmos DB
# =============================================================================

resource "azurerm_private_endpoint" "cosmos" {
  name                = "pe-${var.name_prefix}-cosmos"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "plsc-cosmos"
    private_connection_resource_id = var.cosmos_account_id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["cosmosdb"],
    ]
  }
}

# =============================================================================
# Private Endpoint for AI Search
# =============================================================================

resource "azurerm_private_endpoint" "search" {
  name                = "pe-${var.name_prefix}-search"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "plsc-search"
    private_connection_resource_id = var.search_service_id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["search"],
    ]
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "private_endpoint_ids" {
  value = {
    foundry      = azurerm_private_endpoint.foundry.id
    storage_blob = azurerm_private_endpoint.storage_blob.id
    storage_file = azurerm_private_endpoint.storage_file.id
    cosmos       = azurerm_private_endpoint.cosmos.id
    search       = azurerm_private_endpoint.search.id
  }
}
