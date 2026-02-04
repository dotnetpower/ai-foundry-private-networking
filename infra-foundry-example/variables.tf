# ============================================================================
# Variables for Azure AI Foundry Private Network Agent Setup
# ============================================================================

# ----------------------------------------------------------------------------
# General Settings
# ----------------------------------------------------------------------------

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"

  validation {
    condition = contains([
      "westus", "eastus", "eastus2", "japaneast", "francecentral",
      "spaincentral", "uaenorth", "southcentralus", "italynorth",
      "germanywestcentral", "brazilsouth", "southafricanorth",
      "australiaeast", "swedencentral", "canadaeast", "westeurope",
      "westus3", "uksouth", "southindia", "koreacentral",
      "polandcentral", "switzerlandnorth", "norwayeast"
    ], var.location)
    error_message = "Location must be one of the supported Azure regions for AI Foundry Agents."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-ai-foundry-agent"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# AI Services Settings
# ----------------------------------------------------------------------------

variable "ai_services_name" {
  description = "Base name for AI Services resource"
  type        = string
  default     = "aiservices"
}

variable "model_name" {
  description = "Name of the AI model to deploy"
  type        = string
  default     = "gpt-4.1"
}

variable "model_format" {
  description = "Format/provider of the model"
  type        = string
  default     = "OpenAI"
}

variable "model_version" {
  description = "Version of the model"
  type        = string
  default     = "2025-04-14"
}

variable "model_sku_name" {
  description = "SKU name for model deployment"
  type        = string
  default     = "GlobalStandard"
}

variable "model_capacity" {
  description = "Tokens per minute (TPM) capacity for model deployment"
  type        = number
  default     = 30
}

# ----------------------------------------------------------------------------
# Project Settings
# ----------------------------------------------------------------------------

variable "first_project_name" {
  description = "Base name for the first project"
  type        = string
  default     = "project"
}

variable "project_description" {
  description = "Description for the AI project"
  type        = string
  default     = "A project for the AI Foundry account with network secured deployed Agent"
}

variable "display_name" {
  description = "Display name for the project"
  type        = string
  default     = "network secured agent project"
}

variable "project_cap_host" {
  description = "Name of the project capability host"
  type        = string
  default     = "caphostproj"
}

# ----------------------------------------------------------------------------
# Networking Settings
# ----------------------------------------------------------------------------

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
  default     = "agent-vnet"
}

variable "vnet_address_prefix" {
  description = "Address space for the VNet (e.g., 192.168.0.0/16)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "agent_subnet_name" {
  description = "Name of the Agent subnet"
  type        = string
  default     = "agent-subnet"
}

variable "agent_subnet_prefix" {
  description = "Address prefix for the Agent subnet"
  type        = string
  default     = "" # Will be calculated if empty
}

variable "pe_subnet_name" {
  description = "Name of the Private Endpoint subnet"
  type        = string
  default     = "pe-subnet"
}

variable "pe_subnet_prefix" {
  description = "Address prefix for the Private Endpoint subnet"
  type        = string
  default     = "" # Will be calculated if empty
}

# ----------------------------------------------------------------------------
# Existing Resources (Optional)
# ----------------------------------------------------------------------------

variable "existing_vnet_resource_id" {
  description = "Resource ID of existing VNet to use (leave empty to create new)"
  type        = string
  default     = ""
}

variable "ai_search_resource_id" {
  description = "Resource ID of existing AI Search service (leave empty to create new)"
  type        = string
  default     = ""
}

variable "azure_storage_account_resource_id" {
  description = "Resource ID of existing Storage Account (leave empty to create new)"
  type        = string
  default     = ""
}

variable "azure_cosmos_db_account_resource_id" {
  description = "Resource ID of existing Cosmos DB account (leave empty to create new)"
  type        = string
  default     = ""
}

variable "existing_dns_zones" {
  description = "Map of DNS zone names to their resource group (empty string to create new)"
  type        = map(string)
  default = {
    "privatelink.services.ai.azure.com"       = ""
    "privatelink.openai.azure.com"            = ""
    "privatelink.cognitiveservices.azure.com" = ""
    "privatelink.search.windows.net"          = ""
    "privatelink.blob.core.windows.net"       = ""
    "privatelink.documents.azure.com"         = ""
  }
}
