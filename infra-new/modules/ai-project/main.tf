terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

# =============================================================================
# AI Project (Microsoft.CognitiveServices/accounts/projects)
# =============================================================================

resource "azapi_resource" "ai_project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview"
  name      = var.project_name
  location  = var.location
  parent_id = "${var.resource_group_id}/providers/Microsoft.CognitiveServices/accounts/${var.account_name}"

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      description = var.project_description
      displayName = var.display_name
    }
  }

  response_export_values = ["properties.internalId", "id", "identity"]

  tags = var.tags
}

# =============================================================================
# Project Connections (BYO Resources)
# =============================================================================

# CosmosDB Connection (Thread Storage)
resource "azapi_resource" "connection_cosmosdb" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.cosmos_db_name
  parent_id = azapi_resource.ai_project.id

  body = {
    properties = {
      category = "CosmosDB"
      target   = var.cosmos_db_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.cosmos_db_id
        location   = var.cosmos_db_location
      }
    }
  }

  depends_on = [azapi_resource.ai_project]
}

# Storage Connection (File Storage)
resource "azapi_resource" "connection_storage" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.storage_name
  parent_id = azapi_resource.ai_project.id

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = var.storage_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.storage_id
        location   = var.storage_location
      }
    }
  }

  depends_on = [azapi_resource.ai_project]
}

# AI Search Connection (Vector Store)
resource "azapi_resource" "connection_search" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.ai_search_name
  parent_id = azapi_resource.ai_project.id

  body = {
    properties = {
      category = "CognitiveSearch"
      target   = var.ai_search_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.ai_search_id
        location   = var.ai_search_location
      }
    }
  }

  depends_on = [azapi_resource.ai_project]
}
