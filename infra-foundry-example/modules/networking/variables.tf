# ============================================================================
# Networking Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_address_prefix" {
  description = "Address space for the VNet"
  type        = string
  default     = "192.168.0.0/16"
}

variable "agent_subnet_name" {
  description = "Name of the Agent subnet"
  type        = string
  default     = "agent-subnet"
}

variable "agent_subnet_prefix" {
  description = "Address prefix for Agent subnet (empty to auto-calculate)"
  type        = string
  default     = ""
}

variable "pe_subnet_name" {
  description = "Name of the Private Endpoint subnet"
  type        = string
  default     = "pe-subnet"
}

variable "pe_subnet_prefix" {
  description = "Address prefix for Private Endpoint subnet (empty to auto-calculate)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
