terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
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
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
  storage_use_azuread = true
}

provider "azapi" {}

# 고유 접미사 생성
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true

  lifecycle {
    ignore_changes = [special, upper, length]
  }
}

locals {
  unique_suffix        = random_string.suffix.result
  account_name         = lower("${var.ai_services_name}${local.unique_suffix}")
  project_name         = lower("${var.project_name}${local.unique_suffix}")
  
  # 사용자 지정 접두사가 있으면 사용, 없으면 자동 생성
  cosmos_db_name       = var.cosmosdb_name_prefix != "" ? lower("${var.cosmosdb_name_prefix}${local.unique_suffix}") : lower("${var.ai_services_name}${local.unique_suffix}cosmosdb")
  ai_search_name       = var.ai_search_name_prefix != "" ? lower("${var.ai_search_name_prefix}${local.unique_suffix}") : lower("${var.ai_services_name}${local.unique_suffix}search")
  storage_name         = var.storage_name_prefix != "" ? lower("${var.storage_name_prefix}${local.unique_suffix}") : lower("${var.ai_services_name}${local.unique_suffix}st")
  capability_host_name = "caphostproj"

  common_tags = merge(var.tags, {
    DeployDate = formatdate("YYYYMMDD", timestamp())
  })
}

# =============================================================================
# Resource Group
# =============================================================================
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# =============================================================================
# 네트워킹 - VNet 및 서브넷은 deploy.sh에서 미리 생성됨 (Data Source로 참조)
# =============================================================================
locals {
  # VNet 리소스 그룹 (비어있으면 resource_group_name 사용)
  vnet_rg = var.vnet_resource_group != "" ? var.vnet_resource_group : var.resource_group_name
}

# VNet 데이터 소스 (deploy.sh에서 미리 생성됨)
data "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = local.vnet_rg
}

data "azurerm_subnet" "agent" {
  name                 = var.agent_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = local.vnet_rg
}

data "azurerm_subnet" "pe" {
  name                 = var.pe_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = local.vnet_rg
}

# 로컬 변수로 VNet 정보 통합
locals {
  vnet_id         = data.azurerm_virtual_network.main.id
  vnet_name_used  = data.azurerm_virtual_network.main.name
  agent_subnet_id = data.azurerm_subnet.agent.id
  pe_subnet_id    = data.azurerm_subnet.pe.id
}

# =============================================================================
# 의존 리소스 모듈 (CosmosDB, Storage, AI Search)
# =============================================================================
module "dependent_resources" {
  source = "./modules/dependent-resources"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  cosmos_db_name      = local.cosmos_db_name
  ai_search_name      = local.ai_search_name
  storage_name        = local.storage_name
  search_sku          = var.search_sku
  tags                = local.common_tags

  # VNet이 먼저 존재해야 함
  depends_on = [data.azurerm_virtual_network.main]
}

# =============================================================================
# Private Endpoint 및 DNS 모듈
# =============================================================================
module "private_endpoints" {
  source = "./modules/private-endpoints"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  vnet_id             = local.vnet_id
  vnet_name           = local.vnet_name_used
  pe_subnet_id        = local.pe_subnet_id
  unique_suffix       = local.unique_suffix

  # 연결할 리소스들
  storage_account_id   = module.dependent_resources.storage_account_id
  storage_account_name = local.storage_name
  cosmos_db_id         = module.dependent_resources.cosmos_db_id
  cosmos_db_name       = local.cosmos_db_name
  ai_search_id         = module.dependent_resources.ai_search_id
  ai_search_name       = local.ai_search_name

  tags = local.common_tags

  depends_on = [module.dependent_resources]
}

# =============================================================================
# AI Services Account
# =============================================================================
module "ai_account" {
  source = "./modules/ai-account"

  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  account_name        = local.account_name
  agent_subnet_id     = local.agent_subnet_id
  pe_subnet_id        = local.pe_subnet_id
  vnet_id             = local.vnet_id
  vnet_name           = local.vnet_name_used

  # DNS Zone IDs (private-endpoints 모듈에서 생성)
  private_dns_zone_ids = module.private_endpoints.private_dns_zone_ids

  # 모델 배포 설정
  model_name     = var.model_name
  model_format   = var.model_format
  model_version  = var.model_version
  model_sku_name = var.model_sku_name
  model_capacity = var.model_capacity

  tags = local.common_tags

  depends_on = [module.private_endpoints]
}

# =============================================================================
# AI Project
# =============================================================================
module "ai_project" {
  source = "./modules/ai-project"

  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  account_name        = local.account_name
  project_name        = local.project_name
  project_description = var.project_description
  display_name        = var.display_name

  # 연결 정보
  cosmos_db_name     = local.cosmos_db_name
  cosmos_db_id       = module.dependent_resources.cosmos_db_id
  cosmos_db_endpoint = module.dependent_resources.cosmos_db_endpoint
  cosmos_db_location = var.location

  storage_name       = local.storage_name
  storage_id         = module.dependent_resources.storage_account_id
  storage_endpoint   = module.dependent_resources.storage_blob_endpoint
  storage_location   = var.location

  ai_search_name     = local.ai_search_name
  ai_search_id       = module.dependent_resources.ai_search_id
  ai_search_endpoint = module.dependent_resources.ai_search_endpoint
  ai_search_location = var.location

  tags = local.common_tags

  depends_on = [module.ai_account]
}

# =============================================================================
# RBAC 역할 할당 (Capability Host 생성 전 필수!)
# =============================================================================
module "role_assignments" {
  source = "./modules/role-assignments"

  # Storage 역할 할당
  storage_account_id = module.dependent_resources.storage_account_id

  # CosmosDB 역할 할당
  cosmos_db_id       = module.dependent_resources.cosmos_db_id
  cosmos_db_name     = local.cosmos_db_name
  resource_group_name = azurerm_resource_group.main.name

  # AI Search 역할 할당
  ai_search_id = module.dependent_resources.ai_search_id

  # Project의 System Managed Identity
  project_principal_id = module.ai_project.project_principal_id

  depends_on = [module.ai_project]
}

# =============================================================================
# Capability Host
# =============================================================================
module "capability_host" {
  source = "./modules/capability-host"

  resource_group_id = azurerm_resource_group.main.id
  account_name      = local.account_name
  project_name      = local.project_name
  caphost_name      = local.capability_host_name

  # Connections (Project에서 생성된 연결 이름)
  cosmos_db_connection = local.cosmos_db_name
  storage_connection   = local.storage_name
  ai_search_connection = local.ai_search_name

  # 역할 할당 완료 후 생성 (필수!)
  depends_on = [
    module.role_assignments,
    module.private_endpoints
  ]
}
