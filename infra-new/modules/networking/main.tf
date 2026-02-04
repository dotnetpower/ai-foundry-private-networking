# =============================================================================
# 네트워킹 모듈 - VNet, Subnets, NSG
# =============================================================================

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_prefix]
  tags                = var.tags
}

# Agent 서브넷 (Microsoft.App/environments 위임 - Capability Host용)
resource "azurerm_subnet" "agent" {
  name                 = var.agent_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.agent_subnet_prefix]

  # Microsoft.App/environments에 서브넷 위임 (Agent 워크로드용 필수)
  delegation {
    name = "delegation-app-environments"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  # 아웃바운드 기본 접근 비활성화
  default_outbound_access_enabled = false
}

# Private Endpoint 서브넷
resource "azurerm_subnet" "pe" {
  name                 = var.pe_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.pe_subnet_prefix]

  # Private Endpoint 네트워크 정책 활성화
  private_endpoint_network_policies = "Disabled"

  # 아웃바운드 기본 접근 비활성화
  default_outbound_access_enabled = false
}

# NSG for Agent Subnet
resource "azurerm_network_security_group" "agent" {
  name                = "nsg-${var.agent_subnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# NSG for PE Subnet
resource "azurerm_network_security_group" "pe" {
  name                = "nsg-${var.pe_subnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# NSG Association - Agent Subnet
resource "azurerm_subnet_network_security_group_association" "agent" {
  subnet_id                 = azurerm_subnet.agent.id
  network_security_group_id = azurerm_network_security_group.agent.id
}

# NSG Association - PE Subnet
resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe.id
}
