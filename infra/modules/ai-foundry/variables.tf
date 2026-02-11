variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "resource_group_id" {
  description = "리소스 그룹 ID (azapi 리소스용)"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "storage_account_id" {
  description = "Storage Account ID"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "container_registry_id" {
  description = "Container Registry ID"
  type        = string
}

variable "application_insights_id" {
  description = "Application Insights ID"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}

# Azure OpenAI 연결 설정
variable "openai_resource_id" {
  description = "Azure OpenAI 리소스 ID"
  type        = string
}

variable "openai_endpoint" {
  description = "Azure OpenAI 엔드포인트 URL"
  type        = string
}

variable "openai_api_key" {
  description = "Azure OpenAI API 키 (AAD 인증 사용 시 빈 문자열 가능)"
  type        = string
  default     = ""
  sensitive   = true
}

# AI Search 연결 설정 (선택적)
variable "ai_search_endpoint" {
  description = "Azure AI Search 엔드포인트 URL"
  type        = string
  default     = ""
}

variable "ai_search_api_key" {
  description = "Azure AI Search API 키 (AAD 인증 사용 시 빈 문자열 가능)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ai_search_id" {
  description = "Azure AI Search 리소스 ID (RBAC 할당용)"
  type        = string
  default     = ""
}

variable "enable_ai_search" {
  description = "AI Search 연결 활성화 여부"
  type        = bool
  default     = true
}

variable "subnet_id" {
  description = "Private Endpoint를 배치할 서브넷 ID"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS Zone IDs (azureml, notebooks)"
  type        = map(string)
}
