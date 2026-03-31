# =============================================================================
# Jumpbox Module - Windows VM (Public IP + RDP)
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

variable "jumpbox_subnet_id" {
  type = string
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

# =============================================================================
# Public IP for Windows Jumpbox
# =============================================================================

resource "azurerm_public_ip" "jumpbox" {
  name                = "pip-${var.name_prefix}-jumpbox"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# =============================================================================
# Network Interface
# =============================================================================

resource "azurerm_network_interface" "jumpbox" {
  name                = "nic-${var.name_prefix}-windows"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = var.jumpbox_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

# =============================================================================
# Windows Jumpbox (Windows 11 Pro)
# =============================================================================

resource "azurerm_windows_virtual_machine" "jumpbox" {
  name                  = "vm-${var.name_prefix}-win"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_B2ms"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  computer_name         = "jumpbox-win"
  network_interface_ids = [azurerm_network_interface.jumpbox.id]
  tags                  = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "private_ip" {
  value = azurerm_network_interface.jumpbox.private_ip_address
}

output "public_ip" {
  value = azurerm_public_ip.jumpbox.ip_address
}
