terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
  }
}

# AI Foundry Hub (azapi로 생성 - Hub kind 지원)
resource "azapi_resource" "hub" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-07-01-preview"
  name      = "aihub-foundry"
  location  = var.location
  parent_id = var.resource_group_id

  identity {
    type = "SystemAssigned"
  }

  body = jsonencode({
    kind = "Hub"
    properties = {
      friendlyName        = "AI Foundry Hub"
      description         = "Azure AI Foundry Hub for Agent Development"
      publicNetworkAccess = "Enabled"
      storageAccount      = var.storage_account_id
      keyVault            = var.key_vault_id
      containerRegistry   = var.container_registry_id
      applicationInsights = var.application_insights_id
      managedNetwork = {
        isolationMode = "AllowInternetOutbound"
      }
    }
  })

  tags = var.tags

  response_export_values = ["properties.workspaceId"]
}

# AI Foundry Project (에이전트 개발용)
resource "azapi_resource" "project" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-07-01-preview"
  name      = "aiproj-agents"
  location  = var.location
  parent_id = var.resource_group_id

  identity {
    type = "SystemAssigned"
  }

  body = jsonencode({
    kind = "Project"
    properties = {
      friendlyName        = "Agent Development Project"
      description         = "Project for building AI Agents with GPT models"
      publicNetworkAccess = "Enabled"
      hubResourceId       = azapi_resource.hub.id
    }
  })

  tags = merge(var.tags, {
    WorkspaceType = "Project"
    ParentHub     = "aihub-foundry"
    Purpose       = "AgentDevelopment"
  })

  depends_on = [azapi_resource.hub]

  response_export_values = ["properties.workspaceId"]
}

# =============================================================================
# RBAC 역할 할당 (AAD 인증용)
# =============================================================================

# AI Hub에 Azure OpenAI 접근 권한 부여
resource "azurerm_role_assignment" "hub_openai_user" {
  scope                = var.openai_resource_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.hub.identity[0].principal_id
}

# AI Hub에 AI Search 접근 권한 부여
resource "azurerm_role_assignment" "hub_search_reader" {
  count                = var.enable_ai_search ? 1 : 0
  scope                = var.ai_search_id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azapi_resource.hub.identity[0].principal_id
}

# AI Hub에 Container Registry 접근 권한 부여
resource "azurerm_role_assignment" "hub_acr_pull" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azapi_resource.hub.identity[0].principal_id
}

resource "azurerm_role_assignment" "hub_acr_push" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPush"
  principal_id         = azapi_resource.hub.identity[0].principal_id
}

# =============================================================================
# Connections (AAD 인증)
# =============================================================================

# AI Foundry Hub에 Azure OpenAI 연결 (Managed Identity 인증)
resource "azapi_resource" "openai_connection" {
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-04-01"
  name      = "aoai-connection"
  parent_id = azapi_resource.hub.id

  body = jsonencode({
    properties = {
      category      = "AzureOpenAI"
      target        = var.openai_endpoint
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "azure"
        ApiVersion = "2024-02-15-preview"
        ResourceId = var.openai_resource_id
      }
    }
  })

  depends_on = [azapi_resource.hub]
}

# AI Search 연결 (RAG 패턴용) - Managed Identity 인증
resource "azapi_resource" "search_connection" {
  count     = var.enable_ai_search ? 1 : 0
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-04-01"
  name      = "aisearch-connection"
  parent_id = azapi_resource.hub.id

  body = jsonencode({
    properties = {
      category      = "CognitiveSearch"
      target        = var.ai_search_endpoint
      authType      = "AAD"
      isSharedToAll = true
    }
  })

  depends_on = [azapi_resource.hub]
}

# =============================================================================
# AI Hub Private Endpoint
# =============================================================================

resource "azurerm_private_endpoint" "hub" {
  name                = "pe-aihub"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-aihub"
    private_connection_resource_id = azapi_resource.hub.id
    is_manual_connection           = false
    subresource_names              = ["amlworkspace"]
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["azureml"],
      var.private_dns_zone_ids["notebooks"]
    ]
  }

  depends_on = [azapi_resource.hub]
}
