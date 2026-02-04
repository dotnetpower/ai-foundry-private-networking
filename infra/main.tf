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

  # 로컬 상태 파일 사용 (APIM 추가 배포용)
  # backend "azurerm" {
  #   use_azuread_auth = true
  # }
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
  # 배포 날짜 (변수로 전달되지 않으면 현재 날짜 사용)
  deploy_date = var.deploy_date != "" ? var.deploy_date : formatdate("YYYYMMDD", timestamp())

  # 리소스 그룹 이름 자동 생성
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "rg-${var.project_name}-${local.deploy_date}"

  # 스토리지 계정 이름 자동 생성 (최대 24자, 소문자+숫자만)
  storage_account_name = "st${var.project_name}${local.deploy_date}"

  # 배포 정보 태그 추가
  common_tags = merge(var.tags, {
    DeployDate = local.deploy_date
  })
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Networking 모듈
module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_address_space  = var.vnet_address_space
  subnet_config       = var.subnet_config
  tags                = var.tags
}

# Security 모듈
module "security" {
  source = "./modules/security"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  vnet_id                 = module.networking.vnet_id
  subnet_id               = module.networking.ai_foundry_subnet_id
  private_dns_zone_ids    = module.networking.private_dns_zone_ids
  create_private_dns_zone = false # 이미 존재하는 DNS Zone 사용
  tags                    = var.tags
}

# Storage 모듈
module "storage" {
  source = "./modules/storage"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  storage_account_name = local.storage_account_name
  subnet_id            = module.networking.ai_foundry_subnet_id
  vnet_id              = module.networking.vnet_id
  private_dns_zone_ids = module.networking.private_dns_zone_ids
  tags                 = local.common_tags
}

# Cognitive Services 모듈 (Azure OpenAI 포함)
module "cognitive_services" {
  source = "./modules/cognitive-services"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  subnet_id            = module.networking.ai_foundry_subnet_id
  vnet_id              = module.networking.vnet_id
  private_dns_zone_ids = module.networking.private_dns_zone_ids
  tags                 = var.tags
}

# AI Foundry 모듈
module "ai_foundry" {
  source = "./modules/ai-foundry"

  resource_group_name     = azurerm_resource_group.main.name
  resource_group_id       = azurerm_resource_group.main.id
  location                = azurerm_resource_group.main.location
  storage_account_id      = module.storage.storage_account_id
  key_vault_id            = module.security.key_vault_id
  container_registry_id   = module.storage.container_registry_id
  application_insights_id = module.monitoring.application_insights_id
  subnet_id               = module.networking.ai_foundry_subnet_id
  private_dns_zone_ids    = module.networking.private_dns_zone_ids
  tags                    = var.tags

  # Azure OpenAI 연결 (AAD 인증 - Managed Identity)
  openai_resource_id = module.cognitive_services.openai_id
  openai_endpoint    = module.cognitive_services.openai_endpoint
  openai_api_key     = "" # AAD 인증 사용으로 불필요

  # Azure AI Search 연결 (AAD 인증 - Managed Identity)
  ai_search_endpoint = module.cognitive_services.ai_search_endpoint
  ai_search_api_key  = "" # AAD 인증 사용으로 불필요
  ai_search_id       = module.cognitive_services.ai_search_id

  depends_on = [module.cognitive_services]
}

# Monitoring 모듈
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# Jumpbox 모듈 (East US - 주석 처리됨)
# module "jumpbox" {
#   source = "./modules/jumpbox"
#
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
#   subnet_id           = module.networking.jumpbox_subnet_id
#   admin_username      = var.jumpbox_admin_username
#   admin_password      = var.jumpbox_admin_password
#   tags                = var.tags
# }

# Jumpbox 모듈 (Korea Central)
module "jumpbox_krc" {
  source = "./modules/jumpbox-krc"

  resource_group_name  = azurerm_resource_group.main.name
  jumpbox_location     = "koreacentral"
  main_vnet_id         = module.networking.vnet_id
  main_vnet_name       = module.networking.vnet_name
  admin_username       = var.jumpbox_admin_username
  admin_password       = var.jumpbox_admin_password
  private_dns_zone_ids = module.networking.private_dns_zone_ids
  tags                 = var.tags

  depends_on = [module.networking]
}

# API Management 모듈 (배포 시간이 30-45분 소요)
module "apim" {
  source = "./modules/apim"

  resource_group_name                      = azurerm_resource_group.main.name
  location                                 = azurerm_resource_group.main.location
  subnet_id                                = module.networking.ai_foundry_subnet_id
  publisher_name                           = "AI Foundry Team"
  publisher_email                          = var.publisher_email
  sku_name                                 = var.apim_sku_name
  openai_endpoint                          = module.cognitive_services.openai_hostname
  openai_api_key                           = module.cognitive_services.openai_api_key
  application_insights_id                  = module.monitoring.application_insights_id
  application_insights_instrumentation_key = module.monitoring.application_insights_instrumentation_key
  private_dns_zone_id                      = module.networking.private_dns_zone_ids["apim"]
  tags                                     = var.tags

  depends_on = [
    module.cognitive_services,
    module.monitoring,
    module.networking
  ]
}
