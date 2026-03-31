# =============================================================================
# Main Terraform Template - Azure Foundry Private Networking (Standard Agent)
# =============================================================================
# Based on: https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  subscription_id      = var.subscription_id
  storage_use_azuread  = true  # Use Azure AD auth for storage data plane (required when shared key access is disabled)
}

provider "azapi" {}

# =============================================================================
# Random Suffix (equivalent to uniqueString(resourceGroup().id))
# =============================================================================

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  short_suffix = random_string.suffix.result
  name_prefix  = "aifoundry-${var.environment_name}"
}

# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# =============================================================================
# Networking Module
# =============================================================================

module "networking" {
  source = "./modules/networking"

  resource_group_name                = azurerm_resource_group.main.name
  location                           = azurerm_resource_group.main.location
  name_prefix                        = local.name_prefix
  vnet_address_prefix                = var.vnet_address_prefix
  agent_subnet_address_prefix        = var.agent_subnet_address_prefix
  private_endpoint_subnet_address_prefix = var.private_endpoint_subnet_address_prefix
  jumpbox_subnet_address_prefix      = var.jumpbox_subnet_address_prefix
  deploy_jumpbox_subnet              = var.deploy_jumpbox
  hub_vnet_id                        = var.hub_vnet_id
  hub_vnet_resource_group            = var.hub_vnet_resource_group
  hub_vnet_name                      = var.hub_vnet_name
  allowed_rdp_source_ip              = var.allowed_rdp_source_ip
  tags                               = var.tags
}

# =============================================================================
# Dependent Resources Module (Storage, Cosmos DB, AI Search)
# =============================================================================

module "dependent_resources" {
  source = "./modules/dependent-resources"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  short_suffix        = local.short_suffix
  tags                = var.tags

  depends_on = [module.networking]
}

# =============================================================================
# AI Foundry Module
# =============================================================================

module "ai_foundry" {
  source = "./modules/ai-foundry"

  resource_group_name  = azurerm_resource_group.main.name
  resource_group_id    = azurerm_resource_group.main.id
  location             = azurerm_resource_group.main.location
  short_suffix         = local.short_suffix
  agent_subnet_id      = module.networking.agent_subnet_id
  storage_account_id   = module.dependent_resources.storage_account_id
  storage_account_name = module.dependent_resources.storage_account_name
  cosmos_account_id    = module.dependent_resources.cosmos_account_id
  cosmos_account_name  = module.dependent_resources.cosmos_account_name
  search_service_id    = module.dependent_resources.search_service_id
  search_service_name  = module.dependent_resources.search_service_name
  tags                 = var.tags
}

# =============================================================================
# Private Endpoints Module
# =============================================================================

module "private_endpoints" {
  source = "./modules/private-endpoints"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  name_prefix                = local.name_prefix
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  foundry_account_id         = module.ai_foundry.foundry_account_id
  storage_account_id         = module.dependent_resources.storage_account_id
  cosmos_account_id          = module.dependent_resources.cosmos_account_id
  search_service_id          = module.dependent_resources.search_service_id
  private_dns_zone_ids       = module.networking.private_dns_zone_ids
  tags                       = var.tags

  # Wait for ALL ai_foundry resources (account + models + project + connections + RBAC)
  # to complete before creating PEs — prevents "Account in state Accepted" error
  depends_on = [module.ai_foundry]
}

# =============================================================================
# Capability Host Module (via AzAPI - preview API)
# =============================================================================

module "capability_host" {
  source = "./modules/capability-host"

  foundry_account_id       = module.ai_foundry.foundry_account_id
  foundry_account_name     = module.ai_foundry.foundry_account_name
  foundry_project_name     = module.ai_foundry.foundry_project_name
  cosmos_connection_name   = module.ai_foundry.cosmos_connection_name
  storage_connection_name  = module.ai_foundry.storage_connection_name
  search_connection_name   = module.ai_foundry.search_connection_name

  depends_on = [module.private_endpoints]
}

# =============================================================================
# Jumpbox Module (Optional)
# =============================================================================

module "jumpbox" {
  source = "./modules/jumpbox"
  count  = var.deploy_jumpbox ? 1 : 0

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  jumpbox_subnet_id   = module.networking.jumpbox_subnet_id
  admin_username      = var.jumpbox_admin_username
  admin_password      = var.jumpbox_admin_password
  tags                = var.tags

  depends_on = [module.private_endpoints]
}
