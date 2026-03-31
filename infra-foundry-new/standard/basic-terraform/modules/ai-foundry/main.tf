# =============================================================================
# AI Foundry Module - Foundry Account, Project, Model Deployments, RBAC
# =============================================================================
# Uses AzAPI provider for preview API resources (2025-04-01-preview)
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "azure/azapi"
    }
  }
}

variable "resource_group_name" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "location" {
  type = string
}

variable "short_suffix" {
  type = string
}

variable "agent_subnet_id" {
  type = string
}

variable "storage_account_id" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "cosmos_account_id" {
  type = string
}

variable "cosmos_account_name" {
  type = string
}

variable "search_service_id" {
  type = string
}

variable "search_service_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

# =============================================================================
# User Assigned Managed Identity
# =============================================================================

resource "azurerm_user_assigned_identity" "main" {
  name                = "id-${var.short_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# =============================================================================
# Foundry Account (kind: AIServices) — via AzAPI (preview API)
# =============================================================================

resource "azapi_resource" "foundry_account" {
  type      = "Microsoft.CognitiveServices/accounts@2025-04-01-preview"
  name      = "cog-${var.short_suffix}"
  location  = var.location
  parent_id = var.resource_group_id
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      customSubDomainName    = "cog-${var.short_suffix}"
      publicNetworkAccess    = "Disabled"
      disableLocalAuth       = false
      allowProjectManagement = true
      networkAcls = {
        defaultAction = "Deny"
        bypass        = "AzureServices"
      }
      networkInjections = [
        {
          scenario                 = "agent"
          subnetArmId              = var.agent_subnet_id
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }

  response_export_values = [
    "properties.endpoint",
    "identity.principalId",
  ]
}

# =============================================================================
# GPT-4o Model Deployment
# =============================================================================

resource "azapi_resource" "gpt4o" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview"
  name      = "gpt-4o"
  parent_id = azapi_resource.foundry_account.id

  body = {
    sku = {
      name     = "GlobalStandard"
      capacity = 10
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = "gpt-4o"
        version = "2024-11-20"
      }
      raiPolicyName = "Microsoft.DefaultV2"
    }
  }
}

# =============================================================================
# GPT-5.2 Model Deployment
# =============================================================================

resource "azapi_resource" "gpt52" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview"
  name      = "gpt-5.2"
  parent_id = azapi_resource.foundry_account.id

  body = {
    sku = {
      name     = "GlobalStandard"
      capacity = 10
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = "gpt-5.2"
        version = "2025-12-11"
      }
      raiPolicyName = "Microsoft.DefaultV2"
    }
  }

  depends_on = [azapi_resource.gpt4o]
}

# =============================================================================
# Text Embedding Model Deployment (RAG용 text-embedding-3-large)
# =============================================================================

resource "azapi_resource" "embedding" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview"
  name      = "text-embedding-3-large"
  parent_id = azapi_resource.foundry_account.id

  body = {
    sku = {
      name     = "GlobalStandard"
      capacity = 10
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = "text-embedding-3-large"
        version = "1"
      }
    }
  }

  depends_on = [azapi_resource.gpt52]
}

# =============================================================================
# Foundry Project
# =============================================================================

resource "azapi_resource" "foundry_project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview"
  name      = "proj-${var.short_suffix}"
  location  = var.location
  parent_id = azapi_resource.foundry_account.id
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {}
  }

  schema_validation_enabled = false

  response_export_values = [
    "identity.principalId",
  ]

  depends_on = [azapi_resource.embedding]
}

# =============================================================================
# Project Connections (Storage, Cosmos DB, AI Search)
# =============================================================================

resource "azapi_resource" "storage_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = "storage-connection"
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = "https://${var.storage_account_name}.blob.core.windows.net"
      authType = "AAD"
      metadata = {
        ApiType       = "azure"
        AccountName   = var.storage_account_name
        ContainerName = "agents-data"
        ResourceId    = var.storage_account_id
      }
    }
  }
}

resource "azapi_resource" "cosmos_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = "cosmos-connection"
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category = "CosmosDB"
      target   = "https://${var.cosmos_account_name}.documents.azure.com:443/"
      authType = "AAD"
      metadata = {
        ApiType      = "azure"
        AccountName  = var.cosmos_account_name
        DatabaseName = "agentdb"
        ResourceId   = var.cosmos_account_id
      }
    }
  }
}

resource "azapi_resource" "search_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = "search-connection"
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category = "CognitiveSearch"
      target   = "https://${var.search_service_name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "azure"
        ResourceId = var.search_service_id
      }
    }
  }
}

resource "azapi_resource" "rag_storage_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = "rag-storage-connection"
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = "https://${var.storage_account_name}.blob.core.windows.net"
      authType = "AAD"
      metadata = {
        ApiType       = "azure"
        AccountName   = var.storage_account_name
        ContainerName = "rag-documents"
        ResourceId    = var.storage_account_id
      }
    }
  }
}

# =============================================================================
# Local values for principal IDs
# =============================================================================

locals {
  account_principal_id = azapi_resource.foundry_account.output.identity.principalId
  project_principal_id = azapi_resource.foundry_project.output.identity.principalId
}

# =============================================================================
# RBAC Role Assignments
# =============================================================================

# --- Storage ---

# Storage Blob Data Owner (Account + Project)
resource "azurerm_role_assignment" "storage_blob_owner_account" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = local.account_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_owner_project" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

# Storage Blob Data Contributor (Account + Project)
resource "azurerm_role_assignment" "storage_blob_contributor_account" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.account_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_contributor_project" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

# Storage Queue Data Contributor (Project - Azure Function tool 지원용)
resource "azurerm_role_assignment" "storage_queue_contributor_project" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

# --- Cosmos DB ---

# Cosmos DB Operator (Account + Project)
resource "azurerm_role_assignment" "cosmos_operator_account" {
  scope                = var.cosmos_account_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = local.account_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cosmos_operator_project" {
  scope                = var.cosmos_account_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

# Cosmos DB Built-in Data Contributor (데이터 플레인 RBAC)
resource "azurerm_cosmosdb_sql_role_assignment" "data_contributor_account" {
  resource_group_name = var.resource_group_name
  account_name        = var.cosmos_account_name
  role_definition_id  = "${var.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = local.account_principal_id
  scope               = var.cosmos_account_id
}

resource "azurerm_cosmosdb_sql_role_assignment" "data_contributor_project" {
  resource_group_name = var.resource_group_name
  account_name        = var.cosmos_account_name
  role_definition_id  = "${var.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = local.project_principal_id
  scope               = var.cosmos_account_id
}

# --- AI Search ---

# Search Index Data Contributor (Account + Project)
resource "azurerm_role_assignment" "search_data_contributor_account" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = local.account_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "search_data_contributor_project" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

# Search Service Contributor (Account + Project)
resource "azurerm_role_assignment" "search_service_contributor_account" {
  scope                = var.search_service_id
  role_definition_name = "Search Service Contributor"
  principal_id         = local.account_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "search_service_contributor_project" {
  scope                = var.search_service_id
  role_definition_name = "Search Service Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

# --- Cognitive Services ---

# Cognitive Services OpenAI Contributor (Project)
resource "azurerm_role_assignment" "openai_contributor_project" {
  scope                = azapi_resource.foundry_account.id
  role_definition_name = "Cognitive Services OpenAI Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

# =============================================================================
# Outputs
# =============================================================================

output "foundry_account_id" {
  value = azapi_resource.foundry_account.id
}

output "foundry_account_name" {
  value = azapi_resource.foundry_account.name
}

output "foundry_account_endpoint" {
  value = azapi_resource.foundry_account.output.properties.endpoint
}

output "foundry_project_id" {
  value = azapi_resource.foundry_project.id
}

output "foundry_project_name" {
  value = azapi_resource.foundry_project.name
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.main.id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.main.principal_id
}

output "account_principal_id" {
  value = local.account_principal_id
}

output "project_principal_id" {
  value = local.project_principal_id
}

output "storage_connection_name" {
  value = azapi_resource.storage_connection.name
}

output "cosmos_connection_name" {
  value = azapi_resource.cosmos_connection.name
}

output "search_connection_name" {
  value = azapi_resource.search_connection.name
}
