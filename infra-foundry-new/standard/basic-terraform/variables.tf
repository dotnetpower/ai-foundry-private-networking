# =============================================================================
# Variables
# =============================================================================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Location for all resources"
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-aif-new-tf"
}

variable "environment_name" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "environment_name must be one of: dev, staging, prod"
  }
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vnet_address_prefix" {
  description = "VNet address prefix. Class A (10.0.0.0/8) supported in select regions only."
  type        = string
  default     = "10.0.0.0/16"
}

variable "agent_subnet_address_prefix" {
  description = "Agent subnet address prefix (Microsoft.App/environments delegation)"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_endpoint_subnet_address_prefix" {
  description = "Private endpoint subnet address prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "jumpbox_subnet_address_prefix" {
  description = "Jumpbox subnet address prefix"
  type        = string
  default     = "10.0.2.0/24"
}

# =============================================================================
# Hub-Spoke Configuration
# =============================================================================

variable "hub_vnet_id" {
  description = "Hub VNet resource ID for Hub-Spoke peering (empty = standalone VNet)"
  type        = string
  default     = ""
}

variable "hub_vnet_resource_group" {
  description = "Hub VNet resource group name"
  type        = string
  default     = ""
}

variable "hub_vnet_name" {
  description = "Hub VNet name"
  type        = string
  default     = ""
}

# =============================================================================
# Jumpbox Configuration
# =============================================================================

variable "deploy_jumpbox" {
  description = "Deploy Windows Jumpbox VM"
  type        = bool
  default     = false
}

variable "jumpbox_admin_username" {
  description = "Jumpbox admin username"
  type        = string
  default     = "azureuser"
}

variable "jumpbox_admin_password" {
  description = "Jumpbox admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "allowed_rdp_source_ip" {
  description = "RDP 접속을 허용할 소스 IP (CIDR). 예: 61.80.8.142/32"
  type        = string
  default     = "*"
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "AI-Foundry-Private-Networking"
    ManagedBy   = "Terraform"
  }
}
