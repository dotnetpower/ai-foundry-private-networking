variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "storage_name" {
  description = "Storage Account 이름"
  type        = string
}

variable "ai_search_name" {
  description = "AI Search 서비스 이름"
  type        = string
}

variable "cosmos_db_name" {
  description = "CosmosDB 계정 이름"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}

variable "search_sku" {
  description = "AI Search SKU"
  type        = string
  default     = "basic"
}
