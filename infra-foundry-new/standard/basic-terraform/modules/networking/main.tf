# =============================================================================
# Networking Module - VNet, Subnets, NSG, Private DNS Zones
# =============================================================================

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vnet_address_prefix" {
  type    = string
  default = "10.0.0.0/16"
}

variable "agent_subnet_address_prefix" {
  type    = string
  default = "10.0.0.0/24"
}

variable "private_endpoint_subnet_address_prefix" {
  type    = string
  default = "10.0.1.0/24"
}

variable "jumpbox_subnet_address_prefix" {
  type    = string
  default = "10.0.2.0/24"
}

variable "deploy_jumpbox_subnet" {
  type    = bool
  default = false
}

variable "hub_vnet_id" {
  type    = string
  default = ""
}

variable "hub_vnet_resource_group" {
  type    = string
  default = ""
}

variable "hub_vnet_name" {
  type    = string
  default = ""
}

variable "allowed_rdp_source_ip" {
  type    = string
  default = "*"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# =============================================================================
# Network Security Groups
# =============================================================================

resource "azurerm_network_security_group" "agent" {
  name                = "nsg-${var.name_prefix}-agent"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_endpoint" {
  name                = "nsg-${var.name_prefix}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "jumpbox" {
  count               = var.deploy_jumpbox_subnet ? 1 : 0
  name                = "nsg-${var.name_prefix}-jumpbox"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_rdp_source_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4095
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVNetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# =============================================================================
# Virtual Network
# =============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_prefix]
  tags                = var.tags
}

# Agent Subnet (with Microsoft.App/environments delegation)
resource "azurerm_subnet" "agent" {
  name                              = "snet-agent"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.agent_subnet_address_prefix]
  private_endpoint_network_policies = "Disabled"

  delegation {
    name = "delegation-app-environments"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "agent" {
  subnet_id                 = azurerm_subnet.agent.id
  network_security_group_id = azurerm_network_security_group.agent.id
}

# Private Endpoint Subnet
resource "azurerm_subnet" "private_endpoint" {
  name                              = "snet-privateendpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.private_endpoint_subnet_address_prefix]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint" {
  subnet_id                 = azurerm_subnet.private_endpoint.id
  network_security_group_id = azurerm_network_security_group.private_endpoint.id
}

# Jumpbox Subnet (optional)
resource "azurerm_subnet" "jumpbox" {
  count                             = var.deploy_jumpbox_subnet ? 1 : 0
  name                              = "snet-jumpbox"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.jumpbox_subnet_address_prefix]
  default_outbound_access_enabled   = false
}

resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  count                 = var.deploy_jumpbox_subnet ? 1 : 0
  subnet_id             = azurerm_subnet.jumpbox[0].id
  network_security_group_id = azurerm_network_security_group.jumpbox[0].id
}

# =============================================================================
# Private DNS Zones
# =============================================================================

locals {
  private_dns_zones = [
    "privatelink.cognitiveservices.azure.com",
    "privatelink.openai.azure.com",
    "privatelink.services.ai.azure.com",
    "privatelink.search.windows.net",
    "privatelink.documents.azure.com",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
  ]

  dns_zone_keys = [
    "cognitiveservices",
    "openai",
    "servicesai",
    "search",
    "cosmosdb",
    "blob",
    "file",
  ]
}

resource "azurerm_private_dns_zone" "zones" {
  count               = length(local.private_dns_zones)
  name                = local.private_dns_zones[count.index]
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  count                 = length(local.private_dns_zones)
  name                  = "link-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[count.index].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# Link DNS zones to Hub VNet (for Hub-Spoke DNS resolution)
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  count                 = var.hub_vnet_id != "" ? length(local.private_dns_zones) : 0
  name                  = "link-hub"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[count.index].name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# =============================================================================
# VNet Peering: Spoke → Hub
# =============================================================================

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count                        = var.hub_vnet_id != "" ? 1 : 0
  name                         = "peer-spoke-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.main.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

# =============================================================================
# VNet Peering: Hub → Spoke (cross-RG)
# =============================================================================

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count                        = var.hub_vnet_id != "" ? 1 : 0
  name                         = "peer-hub-to-${var.name_prefix}"
  resource_group_name          = var.hub_vnet_resource_group
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.main.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

# =============================================================================
# Outputs
# =============================================================================

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "agent_subnet_id" {
  value = azurerm_subnet.agent.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoint.id
}

output "jumpbox_subnet_id" {
  value = var.deploy_jumpbox_subnet ? azurerm_subnet.jumpbox[0].id : ""
}

output "private_dns_zone_ids" {
  value = { for i, key in local.dns_zone_keys : key => azurerm_private_dns_zone.zones[i].id }
}
