variable "resource_group_id" {
  description = "리소스 그룹 ID"
  type        = string
}

variable "account_name" {
  description = "AI Services 계정 이름"
  type        = string
}

variable "project_name" {
  description = "AI Project 이름"
  type        = string
}

variable "caphost_name" {
  description = "Capability Host 이름"
  type        = string
}

# Connections (Project에서 생성된 연결 이름)
variable "cosmos_db_connection" {
  description = "CosmosDB Connection 이름"
  type        = string
}

variable "storage_connection" {
  description = "Storage Connection 이름"
  type        = string
}

variable "ai_search_connection" {
  description = "AI Search Connection 이름"
  type        = string
}
