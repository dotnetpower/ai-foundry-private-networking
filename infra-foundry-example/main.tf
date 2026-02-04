# ============================================================================
# Azure AI Foundry Private Network Standard Agent Setup
# Terraform implementation based on Azure Foundry Samples Bicep template
# https://github.com/azure-ai-foundry/foundry-samples
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    key_vault {
      purge_soft_deleted_secrets_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {}

# ============================================================================
# Data Sources
# ============================================================================

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# ============================================================================
# Random Suffix for Unique Names
# ============================================================================

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true

  lifecycle {
    ignore_changes = [special, upper, length]
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  unique_suffix  = random_string.suffix.result
  account_name   = lower("${var.ai_services_name}${local.unique_suffix}")
  project_name   = lower("${var.first_project_name}${local.unique_suffix}")
  cosmos_db_name = lower("${var.ai_services_name}${local.unique_suffix}cosmosdb")
  ai_search_name = lower("${var.ai_services_name}${local.unique_suffix}search")
  storage_name   = lower("${var.ai_services_name}${local.unique_suffix}storage")

  # DNS Zone Names
  dns_zone_names = {
    ai_services        = "privatelink.services.ai.azure.com"
    openai             = "privatelink.openai.azure.com"
    cognitive_services = "privatelink.cognitiveservices.azure.com"
    search             = "privatelink.search.windows.net"
    blob               = "privatelink.blob.core.windows.net"
    cosmos_db          = "privatelink.documents.azure.com"
  }

  # Common tags
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Template    = "ai-foundry-private-network-agent"
  })
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ============================================================================
# Networking Module
# ============================================================================

module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = var.vnet_name
  vnet_address_prefix = var.vnet_address_prefix
  agent_subnet_name   = var.agent_subnet_name
  agent_subnet_prefix = var.agent_subnet_prefix
  pe_subnet_name      = var.pe_subnet_name
  pe_subnet_prefix    = var.pe_subnet_prefix
  tags                = local.common_tags
}

# ============================================================================
# AI Services Account Module
# ============================================================================

module "ai_services" {
  source = "./modules/ai-services"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  account_name        = local.account_name
  model_name          = var.model_name
  model_format        = var.model_format
  model_version       = var.model_version
  model_sku_name      = var.model_sku_name
  model_capacity      = var.model_capacity
  agent_subnet_id     = module.networking.agent_subnet_id
  tags                = local.common_tags

  depends_on = [module.networking]
}

# ============================================================================
# Dependencies Module (Storage, CosmosDB, AI Search)
# ============================================================================

module "dependencies" {
  source = "./modules/dependencies"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  storage_name        = local.storage_name
  cosmos_db_name      = local.cosmos_db_name
  ai_search_name      = local.ai_search_name
  tags                = local.common_tags
}

# ============================================================================
# Private Endpoints Module
# ============================================================================

module "private_endpoints" {
  source = "./modules/private-endpoints"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_id             = module.networking.vnet_id
  pe_subnet_id        = module.networking.pe_subnet_id
  suffix              = local.unique_suffix

  # Resource IDs
  ai_account_id   = module.ai_services.account_id
  ai_account_name = local.account_name
  ai_search_id    = module.dependencies.ai_search_id
  ai_search_name  = local.ai_search_name
  storage_id      = module.dependencies.storage_id
  storage_name    = local.storage_name
  cosmos_db_id    = module.dependencies.cosmos_db_id
  cosmos_db_name  = local.cosmos_db_name

  # DNS Zone Names
  dns_zone_names = local.dns_zone_names

  tags = local.common_tags

  depends_on = [module.ai_services, module.dependencies]
}

# ============================================================================
# AI Project Module
# ============================================================================

module "project" {
  source = "./modules/project"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  account_name          = local.account_name
  account_id            = module.ai_services.account_id
  project_name          = local.project_name
  project_description   = var.project_description
  display_name          = var.display_name
  project_cap_host_name = var.project_cap_host

  # Dependencies info
  ai_search_name        = local.ai_search_name
  ai_search_id          = module.dependencies.ai_search_id
  cosmos_db_name        = local.cosmos_db_name
  cosmos_db_id          = module.dependencies.cosmos_db_id
  cosmos_db_endpoint    = module.dependencies.cosmos_db_endpoint
  storage_name          = local.storage_name
  storage_id            = module.dependencies.storage_id
  storage_blob_endpoint = module.dependencies.storage_blob_endpoint

  tags = local.common_tags

  depends_on = [module.private_endpoints]
}

# ============================================================================
# RBAC Module
# ============================================================================

module "rbac" {
  source = "./modules/rbac"

  resource_group_name  = azurerm_resource_group.main.name
  project_principal_id = module.project.project_principal_id
  project_workspace_id = module.project.project_workspace_id

  # Resource IDs
  storage_id     = module.dependencies.storage_id
  storage_name   = local.storage_name
  cosmos_db_id   = module.dependencies.cosmos_db_id
  cosmos_db_name = local.cosmos_db_name
  ai_search_id   = module.dependencies.ai_search_id
  ai_search_name = local.ai_search_name

  depends_on = [module.project]
}
