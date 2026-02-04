variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "resource_group_id" {
  description = "리소스 그룹 ID"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "account_name" {
  description = "AI Services 계정 이름"
  type        = string
}

variable "agent_subnet_id" {
  description = "Agent 서브넷 ID (Microsoft.App/environments 위임됨)"
  type        = string
}

variable "pe_subnet_id" {
  description = "Private Endpoint 서브넷 ID"
  type        = string
}

variable "vnet_id" {
  description = "VNet ID"
  type        = string
}

variable "vnet_name" {
  description = "VNet 이름"
  type        = string
}

# Private DNS Zone IDs
variable "private_dns_zone_ids" {
  description = "Private DNS Zone IDs"
  type = object({
    cognitiveservices = string
    openai            = string
    services_ai       = string
    blob              = string
    documents         = string
    search            = string
  })
}

# 모델 배포 변수
variable "model_name" {
  description = "모델 이름"
  type        = string
}

variable "model_format" {
  description = "모델 형식"
  type        = string
}

variable "model_version" {
  description = "모델 버전"
  type        = string
}

variable "model_sku_name" {
  description = "모델 SKU"
  type        = string
}

variable "model_capacity" {
  description = "모델 용량 (TPM)"
  type        = number
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
