# ============================================================================
# Private Endpoints Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_id" {
  description = "ID of the Virtual Network"
  type        = string
}

variable "pe_subnet_id" {
  description = "ID of the Private Endpoint subnet"
  type        = string
}

variable "suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

# Resource IDs
variable "ai_account_id" {
  description = "ID of the AI Services account"
  type        = string
}

variable "ai_account_name" {
  description = "Name of the AI Services account"
  type        = string
}

variable "ai_search_id" {
  description = "ID of the AI Search service"
  type        = string
}

variable "ai_search_name" {
  description = "Name of the AI Search service"
  type        = string
}

variable "storage_id" {
  description = "ID of the Storage Account"
  type        = string
}

variable "storage_name" {
  description = "Name of the Storage Account"
  type        = string
}

variable "cosmos_db_id" {
  description = "ID of the Cosmos DB account"
  type        = string
}

variable "cosmos_db_name" {
  description = "Name of the Cosmos DB account"
  type        = string
}

variable "dns_zone_names" {
  description = "DNS Zone names for private endpoints"
  type = object({
    ai_services        = string
    openai             = string
    cognitive_services = string
    search             = string
    blob               = string
    cosmos_db          = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
