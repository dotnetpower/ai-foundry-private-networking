variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "subnet_id" {
  description = "APIM이 배포될 서브넷 ID"
  type        = string
}

variable "publisher_name" {
  description = "APIM Publisher 이름"
  type        = string
  default     = "AI Foundry Team"
}

variable "publisher_email" {
  description = "APIM Publisher 이메일"
  type        = string
  default     = "admin@example.com"
}

variable "sku_name" {
  description = "APIM SKU (Developer, Basic, Standard, Premium)"
  type        = string
  default     = "Developer_1"
}

variable "openai_endpoint" {
  description = "Azure OpenAI 엔드포인트 (예: aoai-xxx.openai.azure.com)"
  type        = string
}

variable "openai_api_key" {
  description = "Azure OpenAI API Key"
  type        = string
  sensitive   = true
}

variable "application_insights_id" {
  description = "Application Insights 리소스 ID"
  type        = string
}

variable "application_insights_instrumentation_key" {
  description = "Application Insights Instrumentation Key"
  type        = string
  sensitive   = true
}

variable "private_dns_zone_id" {
  description = "APIM Private DNS Zone ID"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
