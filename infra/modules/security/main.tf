data "azurerm_client_config" "current" {}

# User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "main" {
  name                = "id-aifoundry"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "kv-aif-${random_string.suffix.result}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = var.tags
}

# Random suffix for Key Vault (전역 고유성 보장)
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Key Vault Access Policy for current user
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update",
    "Recover", "Backup", "Restore", "Purge"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete",
    "Recover", "Backup", "Restore", "Purge"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update",
    "Recover", "Backup", "Restore", "Purge"
  ]
}

# Key Vault Access Policy for Managed Identity
resource "azurerm_key_vault_access_policy" "managed_identity" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.main.principal_id

  key_permissions = [
    "Get", "List"
  ]

  secret_permissions = [
    "Get", "List"
  ]

  certificate_permissions = [
    "Get", "List"
  ]
}

# Note: Private DNS Zone for Key Vault is managed by the networking module
# (privatelink.vaultcore.azure.net)
