# ============================================================================
# Project Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "account_name" {
  description = "Name of the parent AI Services account"
  type        = string
}

variable "account_id" {
  description = "ID of the parent AI Services account"
  type        = string
}

variable "project_name" {
  description = "Name of the AI Project"
  type        = string
}

variable "project_description" {
  description = "Description of the AI Project"
  type        = string
  default     = "AI Foundry Project with network secured Agent"
}

variable "display_name" {
  description = "Display name of the AI Project"
  type        = string
  default     = "Network Secured Agent Project"
}

variable "project_cap_host_name" {
  description = "Name of the project capability host"
  type        = string
  default     = "caphostproj"
}

# Dependencies
variable "ai_search_name" {
  description = "Name of the AI Search service"
  type        = string
}

variable "ai_search_id" {
  description = "ID of the AI Search service"
  type        = string
}

variable "cosmos_db_name" {
  description = "Name of the Cosmos DB account"
  type        = string
}

variable "cosmos_db_id" {
  description = "ID of the Cosmos DB account"
  type        = string
}

variable "cosmos_db_endpoint" {
  description = "Endpoint of the Cosmos DB account"
  type        = string
}

variable "storage_name" {
  description = "Name of the Storage account"
  type        = string
}

variable "storage_id" {
  description = "ID of the Storage account"
  type        = string
}

variable "storage_blob_endpoint" {
  description = "Blob endpoint of the Storage account"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
