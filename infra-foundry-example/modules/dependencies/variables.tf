# ============================================================================
# Dependencies Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "storage_name" {
  description = "Name of the Storage Account"
  type        = string
}

variable "cosmos_db_name" {
  description = "Name of the Cosmos DB account"
  type        = string
}

variable "ai_search_name" {
  description = "Name of the AI Search service"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
