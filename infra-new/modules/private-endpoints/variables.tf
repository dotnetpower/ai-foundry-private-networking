variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
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

variable "pe_subnet_id" {
  description = "Private Endpoint 서브넷 ID"
  type        = string
}

variable "unique_suffix" {
  description = "고유 접미사"
  type        = string
}

variable "storage_account_id" {
  description = "Storage Account ID"
  type        = string
}

variable "storage_account_name" {
  description = "Storage Account 이름"
  type        = string
}

variable "cosmos_db_id" {
  description = "CosmosDB ID"
  type        = string
}

variable "cosmos_db_name" {
  description = "CosmosDB 이름"
  type        = string
}

variable "ai_search_id" {
  description = "AI Search ID"
  type        = string
}

variable "ai_search_name" {
  description = "AI Search 이름"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
