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

variable "project_name" {
  description = "Project 이름"
  type        = string
}

variable "project_description" {
  description = "Project 설명"
  type        = string
}

variable "display_name" {
  description = "Project 표시 이름"
  type        = string
}

# CosmosDB Connection
variable "cosmos_db_name" {
  description = "CosmosDB 계정 이름 (Connection 이름으로도 사용)"
  type        = string
}

variable "cosmos_db_id" {
  description = "CosmosDB 계정 ID"
  type        = string
}

variable "cosmos_db_endpoint" {
  description = "CosmosDB 엔드포인트"
  type        = string
}

variable "cosmos_db_location" {
  description = "CosmosDB 리전"
  type        = string
}

# Storage Connection
variable "storage_name" {
  description = "Storage 계정 이름 (Connection 이름으로도 사용)"
  type        = string
}

variable "storage_id" {
  description = "Storage 계정 ID"
  type        = string
}

variable "storage_endpoint" {
  description = "Storage Blob 엔드포인트"
  type        = string
}

variable "storage_location" {
  description = "Storage 리전"
  type        = string
}

# AI Search Connection
variable "ai_search_name" {
  description = "AI Search 서비스 이름 (Connection 이름으로도 사용)"
  type        = string
}

variable "ai_search_id" {
  description = "AI Search 서비스 ID"
  type        = string
}

variable "ai_search_endpoint" {
  description = "AI Search 엔드포인트"
  type        = string
}

variable "ai_search_location" {
  description = "AI Search 리전"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
