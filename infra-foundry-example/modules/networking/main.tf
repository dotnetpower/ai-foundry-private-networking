# ============================================================================
# Networking Module - VNet, Subnets
# ============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Calculate subnet prefixes from VNet address space if not provided
  vnet_address      = var.vnet_address_prefix
  agent_subnet_cidr = var.agent_subnet_prefix != "" ? var.agent_subnet_prefix : cidrsubnet(local.vnet_address, 8, 0)
  pe_subnet_cidr    = var.pe_subnet_prefix != "" ? var.pe_subnet_prefix : cidrsubnet(local.vnet_address, 8, 1)
}

# ============================================================================
# Virtual Network
# ============================================================================

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [local.vnet_address]
  tags                = var.tags
}

# ============================================================================
# Subnets
# ============================================================================

# Agent Subnet - Delegated to Microsoft.App/environments for AI Agent
resource "azurerm_subnet" "agent" {
  name                 = var.agent_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.agent_subnet_cidr]

  delegation {
    name = "Microsoft-app-environments"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  default_outbound_access_enabled = false
}

# Private Endpoint Subnet
resource "azurerm_subnet" "pe" {
  name                              = var.pe_subnet_name
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [local.pe_subnet_cidr]
  private_endpoint_network_policies = "Disabled"

  default_outbound_access_enabled = false
}

# ============================================================================
# Network Security Groups
# ============================================================================

resource "azurerm_network_security_group" "agent" {
  name                = "nsg-${var.agent_subnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "pe" {
  name                = "nsg-${var.pe_subnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ============================================================================
# NSG Associations
# ============================================================================

resource "azurerm_subnet_network_security_group_association" "agent" {
  subnet_id                 = azurerm_subnet.agent.id
  network_security_group_id = azurerm_network_security_group.agent.id
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe.id
}
