# ============================================================================
# Project Module - AI Project with Connections and Capability Host
# ============================================================================

terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

data "azurerm_client_config" "current" {}

# ============================================================================
# AI Project
# ============================================================================

resource "azapi_resource" "project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview"
  name      = var.project_name
  location  = var.location
  parent_id = var.account_id

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      description = var.project_description
      displayName = var.display_name
    }
  }

  tags = var.tags

  response_export_values = ["identity.principalId", "properties.internalId"]
}

# ============================================================================
# Connections
# ============================================================================

# Cosmos DB Connection
resource "azapi_resource" "connection_cosmos_db" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.cosmos_db_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      category = "CosmosDB"
      target   = var.cosmos_db_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.cosmos_db_id
        location   = var.location
      }
    }
  }

  depends_on = [azapi_resource.project]
}

# Storage Account Connection
resource "azapi_resource" "connection_storage" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.storage_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = var.storage_blob_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.storage_id
        location   = var.location
      }
    }
  }

  depends_on = [azapi_resource.project]
}

# AI Search Connection
resource "azapi_resource" "connection_ai_search" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.ai_search_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      category = "CognitiveSearch"
      target   = "https://${var.ai_search_name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.ai_search_id
        location   = var.location
      }
    }
  }

  depends_on = [azapi_resource.project]
}

# ============================================================================
# Capability Host for Agents
# ============================================================================

resource "azapi_resource" "capability_host" {
  type      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name      = var.project_cap_host_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      capabilityHostKind       = "Agents"
      vectorStoreConnections   = [var.ai_search_name]
      storageConnections       = [var.storage_name]
      threadStorageConnections = [var.cosmos_db_name]
    }
  }

  depends_on = [
    azapi_resource.connection_cosmos_db,
    azapi_resource.connection_storage,
    azapi_resource.connection_ai_search,
  ]
}

# ============================================================================
# Local Variables for Workspace ID Formatting
# ============================================================================

locals {
  # Format the workspace ID as GUID
  workspace_id_raw = jsondecode(azapi_resource.project.output).properties.internalId
  workspace_id_guid = format("%s-%s-%s-%s-%s",
    substr(local.workspace_id_raw, 0, 8),
    substr(local.workspace_id_raw, 8, 4),
    substr(local.workspace_id_raw, 12, 4),
    substr(local.workspace_id_raw, 16, 4),
    substr(local.workspace_id_raw, 20, 12)
  )
}
