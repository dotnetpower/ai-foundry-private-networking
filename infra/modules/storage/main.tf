terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Current user/service principal data
data "azurerm_client_config" "current" {}

# RBAC: Storage Blob Data Contributor (OAuth 인증용)
resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# RBAC: Storage Account Contributor (컨테이너 관리용)
resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Storage Account - Blob Container (azapi로 생성 - 네트워크 제한 우회)
# azurerm_storage_container는 public_network_access_enabled=false일 때 접근 불가
resource "azapi_resource" "container_data" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  name      = "data"
  parent_id = "${azurerm_storage_account.main.id}/blobServices/default"

  body = {
    properties = {
      publicAccess = "None"
    }
  }

  depends_on = [
    azurerm_role_assignment.storage_blob_contributor,
    azurerm_role_assignment.storage_account_contributor
  ]
}

resource "azapi_resource" "container_models" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  name      = "models"
  parent_id = "${azurerm_storage_account.main.id}/blobServices/default"

  body = {
    properties = {
      publicAccess = "None"
    }
  }

  depends_on = [
    azurerm_role_assignment.storage_blob_contributor,
    azurerm_role_assignment.storage_account_contributor
  ]
}

# Private Endpoint for Blob
resource "azurerm_private_endpoint" "blob" {
  name                = "pe-storage-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-storage-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "pdnsz-group-blob"
    private_dns_zone_ids = [var.private_dns_zone_ids["blob"]]
  }
}

# Private Endpoint for File
resource "azurerm_private_endpoint" "file" {
  name                = "pe-storage-file"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-storage-file"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "pdnsz-group-file"
    private_dns_zone_ids = [var.private_dns_zone_ids["file"]]
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                          = "acraifoundry${random_string.suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false

  network_rule_set {
    default_action = "Deny"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Random suffix for ACR (전역 고유성 보장)
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false

  lifecycle {
    ignore_changes = [special, upper, length]
  }
}

# Private Endpoint for Container Registry
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.main.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name = "pdnsz-group-acr"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.acr.id
    ]
  }
}

# Private DNS Zone for Container Registry
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Private DNS Zone VNet Link for Container Registry
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "link-acr"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}
