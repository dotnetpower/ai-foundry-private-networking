# =============================================================================
# 공통 변수
# =============================================================================
variable "location" {
  description = "Azure 리전 (Standard Agent는 특정 리전만 지원)"
  type        = string
  default     = "eastus"

  validation {
    condition = contains([
      "westus", "eastus", "eastus2", "japaneast", "francecentral", "spaincentral",
      "uaenorth", "southcentralus", "italynorth", "germanywestcentral", "brazilsouth",
      "southafricanorth", "australiaeast", "swedencentral", "canadaeast",
      "westeurope", "westus3", "uksouth", "southindia", "koreacentral",
      "polandcentral", "switzerlandnorth", "norwayeast"
    ], var.location)
    error_message = "Standard Agent Setup은 특정 리전만 지원합니다."
  }
}

variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
  default     = "rg-aifoundry-agent"
}

variable "tags" {
  description = "모든 리소스에 적용할 태그"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "AI-Foundry-Agent"
    ManagedBy   = "Terraform"
  }
}

# =============================================================================
# AI Services 변수
# =============================================================================
variable "ai_services_name" {
  description = "AI Services 계정 이름 접두사"
  type        = string
  default     = "aiservices"
}

variable "project_name" {
  description = "AI Project 이름 접두사"
  type        = string
  default     = "project"
}

variable "project_description" {
  description = "Project 설명"
  type        = string
  default     = "AI Foundry Agent Project with Private Network"
}

variable "display_name" {
  description = "Project 표시 이름"
  type        = string
  default     = "Network Secured Agent Project"
}

# =============================================================================
# 모델 배포 변수
# =============================================================================
variable "model_name" {
  description = "배포할 모델 이름"
  type        = string
  default     = "gpt-4o"
}

variable "model_format" {
  description = "모델 형식"
  type        = string
  default     = "OpenAI"
}

variable "model_version" {
  description = "모델 버전"
  type        = string
  default     = "2024-11-20"
}

variable "model_sku_name" {
  description = "모델 SKU 이름"
  type        = string
  default     = "GlobalStandard"
}

variable "model_capacity" {
  description = "모델 TPM 용량 (1000 TPM 단위)"
  type        = number
  default     = 30
}

# =============================================================================
# 네트워킹 변수
# =============================================================================

# VNet 리소스 그룹 (별도 관리 시)
variable "vnet_resource_group" {
  description = "VNet 리소스 그룹 (비워두면 resource_group_name 사용)"
  type        = string
  default     = ""
}

# VNet 설정 (스크립트에서 미리 생성)
variable "vnet_name" {
  description = "VNet 이름"
  type        = string
  default     = "vnet-agent"
}

variable "agent_subnet_name" {
  description = "Agent 서브넷 이름 (Microsoft.App/environments 위임됨)"
  type        = string
  default     = "agent-subnet"
}

variable "pe_subnet_name" {
  description = "Private Endpoint 서브넷 이름"
  type        = string
  default     = "pe-subnet"
}
# =============================================================================
# 리소스 이름 변수 (선택적 - 비워두면 자동 생성)
# =============================================================================
variable "storage_name_prefix" {
  description = "Storage Account 이름 접두사 (3-15자, 소문자/숫자만). 비워두면 자동 생성"
  type        = string
  default     = ""
}

variable "cosmosdb_name_prefix" {
  description = "CosmosDB 이름 접두사. 비워두면 자동 생성"
  type        = string
  default     = ""
}

variable "ai_search_name_prefix" {
  description = "AI Search 이름 접두사. 비워두면 자동 생성"
  type        = string
  default     = ""
}

variable "search_sku" {
  description = "AI Search SKU (basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2)"
  type        = string
  default     = "basic"

  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3", "storage_optimized_l1", "storage_optimized_l2"], var.search_sku)
    error_message = "유효한 SKU: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2"
  }
}