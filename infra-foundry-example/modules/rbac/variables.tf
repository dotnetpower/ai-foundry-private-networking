# ============================================================================
# RBAC Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "project_principal_id" {
  description = "Principal ID of the AI Project"
  type        = string
}

variable "project_workspace_id" {
  description = "Workspace ID of the AI Project (formatted as GUID)"
  type        = string
}

# Storage
variable "storage_id" {
  description = "ID of the Storage Account"
  type        = string
}

variable "storage_name" {
  description = "Name of the Storage Account"
  type        = string
}

# Cosmos DB
variable "cosmos_db_id" {
  description = "ID of the Cosmos DB account"
  type        = string
}

variable "cosmos_db_name" {
  description = "Name of the Cosmos DB account"
  type        = string
}

# AI Search
variable "ai_search_id" {
  description = "ID of the AI Search service"
  type        = string
}

variable "ai_search_name" {
  description = "Name of the AI Search service"
  type        = string
}
