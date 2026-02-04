variable "storage_account_id" {
  description = "Storage Account ID"
  type        = string
}

variable "cosmos_db_id" {
  description = "CosmosDB 계정 ID"
  type        = string
}

variable "cosmos_db_name" {
  description = "CosmosDB 계정 이름"
  type        = string
}

variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "ai_search_id" {
  description = "AI Search 서비스 ID"
  type        = string
}

variable "project_principal_id" {
  description = "Project System Managed Identity Principal ID"
  type        = string
}
