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
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # Storage Account OAuth 인증 사용 (키 인증 문제 회피)
  storage_use_azuread = true
}

provider "azapi" {}

# 배포 날짜 및 자동 이름 생성
locals {
  deploy_date = var.deploy_date != "" ? var.deploy_date : formatdate("YYYYMMDD", timestamp())

  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "rg-${var.project_name}-${local.deploy_date}"

  storage_account_name = "st${var.project_name}${local.deploy_date}"

  common_tags = merge(var.tags, {
    DeployDate = local.deploy_date
  })
}

# 배포 시간 측정
resource "time_static" "deploy_start" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# =============================================================================
# Networking 모듈 (VNet, Subnets, NSGs, Private DNS Zones)
# =============================================================================
module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_address_space  = var.vnet_address_space
  subnet_config       = var.subnet_config
  tags                = local.common_tags
}

# =============================================================================
# Security 모듈 (Key Vault, Managed Identity + Key Vault PE)
# =============================================================================
module "security" {
  source = "./modules/security"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  tags                 = local.common_tags
  subnet_id            = module.networking.ai_foundry_subnet_id
  private_dns_zone_ids = module.networking.private_dns_zone_ids

  depends_on = [module.networking]
}

# =============================================================================
# Storage 모듈 (Storage Account, ACR + Private Endpoints)
# =============================================================================
module "storage" {
  source = "./modules/storage"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  storage_account_name = local.storage_account_name
  tags                 = local.common_tags
  subnet_id            = module.networking.ai_foundry_subnet_id
  private_dns_zone_ids = module.networking.private_dns_zone_ids

  depends_on = [module.networking]
}

# =============================================================================
# Cognitive Services 모듈 (Azure OpenAI, AI Search + Private Endpoints)
# =============================================================================
module "cognitive_services" {
  source = "./modules/cognitive-services"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  tags                 = local.common_tags
  subnet_id            = module.networking.ai_foundry_subnet_id
  private_dns_zone_ids = module.networking.private_dns_zone_ids

  depends_on = [module.networking]
}

# =============================================================================
# Monitoring 모듈 (Log Analytics, Application Insights)
# =============================================================================
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

# =============================================================================
# AI Foundry 모듈 (Hub, Project, Connections, RBAC + Hub PE)
# =============================================================================
module "ai_foundry" {
  source = "./modules/ai-foundry"

  resource_group_name     = azurerm_resource_group.main.name
  resource_group_id       = azurerm_resource_group.main.id
  location                = azurerm_resource_group.main.location
  storage_account_id      = module.storage.storage_account_id
  key_vault_id            = module.security.key_vault_id
  container_registry_id   = module.storage.container_registry_id
  application_insights_id = module.monitoring.application_insights_id
  tags                    = local.common_tags
  subnet_id               = module.networking.ai_foundry_subnet_id
  private_dns_zone_ids    = module.networking.private_dns_zone_ids

  # Azure OpenAI 연결 (AAD 인증)
  openai_resource_id = module.cognitive_services.openai_id
  openai_endpoint    = module.cognitive_services.openai_endpoint
  openai_api_key     = ""

  # Azure AI Search 연결 (AAD 인증)
  ai_search_endpoint = module.cognitive_services.ai_search_endpoint
  ai_search_api_key  = ""
  ai_search_id       = module.cognitive_services.ai_search_id

  depends_on = [
    module.networking,
    module.cognitive_services,
    module.storage,
    module.security,
    module.monitoring
  ]
}

# =============================================================================
# 사용자 RBAC 역할 할당 (AI Foundry Portal 접근용)
# =============================================================================

data "azurerm_client_config" "current" {}

# AI Search - 사용자가 AI Foundry에서 Search 연결을 사용하려면 필수
resource "azurerm_role_assignment" "user_search_index_data_reader" {
  scope                = module.cognitive_services.ai_search_id
  role_definition_name = "Search Index Data Reader"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "user_search_index_data_contributor" {
  scope                = module.cognitive_services.ai_search_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "user_search_service_contributor" {
  scope                = module.cognitive_services.ai_search_id
  role_definition_name = "Search Service Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# =============================================================================
# Jumpbox 모듈 (Linux VM + Azure Bastion)
# =============================================================================
module "jumpbox" {
  source = "./modules/jumpbox"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  jumpbox_subnet_id   = module.networking.jumpbox_subnet_id
  bastion_subnet_id   = module.networking.bastion_subnet_id
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  enable_bastion      = var.enable_bastion
  enable_windows_jumpbox = true
  tags                = local.common_tags

  depends_on = [module.networking]
}
