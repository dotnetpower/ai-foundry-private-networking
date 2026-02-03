variable "resource_group_name" {
  description = "리소스 그룹 이름 (비어있으면 자동 생성: rg-aifoundry-YYYYMMDD)"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure 리전"
  type        = string
  default     = "koreacentral"
}

variable "environment" {
  description = "환경 구분 (dev, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "aifoundry"
}

variable "deploy_date" {
  description = "배포 날짜 (YYYYMMDD 형식, 비어있으면 자동 생성)"
  type        = string
  default     = ""
}

variable "vnet_address_space" {
  description = "VNet 주소 공간"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_config" {
  description = "서브넷 구성"
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = list(string)
  }))
  default = {
    ai_foundry = {
      address_prefixes  = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
    }
    jumpbox = {
      address_prefixes  = ["10.0.2.0/24"]
      service_endpoints = []
    }
  }
}

# storage_account_name 변수 제거됨 - locals에서 자동 생성

variable "jumpbox_admin_username" {
  description = "Jumpbox 관리자 사용자명"
  type        = string
  sensitive   = true
  default     = "azureuser"
}

variable "jumpbox_admin_password" {
  description = "Jumpbox 관리자 비밀번호 (환경 변수로 설정: export TF_VAR_jumpbox_admin_password='YourSecurePassword')"
  type        = string
  sensitive   = true
  # 보안상 기본값 제거 - 반드시 환경 변수 또는 tfvars 파일로 제공 필요
  # 최소 요구사항: 12자 이상, 대소문자, 숫자, 특수문자 포함
}

variable "publisher_email" {
  description = "API Management 게시자 이메일"
  type        = string
  default     = "admin@example.com"
}

variable "apim_sku_name" {
  description = "API Management SKU 이름"
  type        = string
  default     = "Developer_1"
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "AI Foundry Private Networking"
    ManagedBy   = "Terraform"
  }
}
