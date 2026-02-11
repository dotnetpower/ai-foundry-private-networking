# Azure OpenAI Service
resource "azurerm_cognitive_account" "openai" {
  name                          = "aoai-aifoundry"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = "aoai-aifoundry-${random_string.openai_suffix.result}"
  public_network_access_enabled = false
  local_auth_enabled            = true

  network_acls {
    default_action = "Deny"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Random suffix for OpenAI subdomain (전역 고유성 보장)
resource "random_string" "openai_suffix" {
  length  = 8
  special = false
  upper   = false

  lifecycle {
    ignore_changes = [special, upper, length]
  }
}

# OpenAI Deployment - GPT-4o (최신 GA 버전: 2024-11-20)
resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }

  scale {
    type     = "Standard"
    capacity = 10
  }
}

# OpenAI Deployment - Text Embedding Ada 002
resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-ada-002"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002"
    version = "2"
  }

  scale {
    type     = "Standard"
    capacity = 10
  }
}

# Azure AI Search
resource "azurerm_search_service" "main" {
  name                          = "srch-aifoundry-${random_string.suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "standard"
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Random suffix for AI Search (전역 고유성 보장)
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false

  lifecycle {
    ignore_changes = [special, upper, length]
  }
}

# =============================================================================
# Private Endpoints
# =============================================================================

# Azure OpenAI Private Endpoint
resource "azurerm_private_endpoint" "openai" {
  name                = "pe-openai"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-openai"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids["openai"]]
  }
}

# AI Search Private Endpoint
resource "azurerm_private_endpoint" "search" {
  name                = "pe-search"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-search"
    private_connection_resource_id = azurerm_search_service.main.id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids["search"]]
  }
}
