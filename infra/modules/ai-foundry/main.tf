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
  type      = "Microsoft.MachineLearningServices/workspaces@2024-04-01"
  name      = "aihub-foundry"
  location  = var.location
  parent_id = var.resource_group_id  # data source 대신 직접 변수 사용

  identity {
    type = "SystemAssigned"
  }

  body = jsonencode({
    kind = "Hub"
    properties = {
      friendlyName        = "AI Foundry Hub"
      description         = "Azure AI Foundry Hub for Agent Development"
      publicNetworkAccess = "Disabled"
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
  type      = "Microsoft.MachineLearningServices/workspaces@2024-04-01"
  name      = "aiproj-agents"
  location  = var.location
  parent_id = var.resource_group_id  # data source 대신 직접 변수 사용

  identity {
    type = "SystemAssigned"
  }

  body = jsonencode({
    kind = "Project"
    properties = {
      friendlyName        = "Agent Development Project"
      description         = "Project for building AI Agents with GPT models"
      publicNetworkAccess = "Disabled"
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

# Private Endpoint for AI Hub
resource "azurerm_private_endpoint" "ai_hub" {
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
    name                 = "pdnsz-group-aihub"
    private_dns_zone_ids = [var.private_dns_zone_ids["azureml"]]
  }
}

# Private Endpoint for AI Project - 주석 처리
# Azure AI Foundry에서는 Project에 별도 Private Endpoint를 생성할 수 없음
# Hub의 Private Endpoint가 Project도 커버함
# resource "azurerm_private_endpoint" "ai_project" {
#   name                = "pe-aiproject"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   subnet_id           = var.subnet_id
#   tags                = var.tags
#
#   private_service_connection {
#     name                           = "psc-aiproject"
#     private_connection_resource_id = azapi_resource.project.id
#     is_manual_connection           = false
#     subresource_names              = ["amlworkspace"]
#   }
#
#   private_dns_zone_group {
#     name                 = "pdnsz-group-aiproject"
#     private_dns_zone_ids = [var.private_dns_zone_ids["azureml"]]
#   }
# }

# Compute Cluster (학습/추론용) - Hub/Project 둘 다 AmlCompute 지원 안됨
# AI Foundry에서는 Serverless Compute 또는 Azure ML Studio에서 직접 생성 필요
# resource "azapi_resource" "compute_cluster" {
#   type      = "Microsoft.MachineLearningServices/workspaces/computes@2024-04-01"
#   name      = "cpu-cluster"
#   location  = var.location
#   parent_id = azapi_resource.hub.id  # Hub로 변경
#
#   body = jsonencode({
#     properties = {
#       computeType = "AmlCompute"
#       properties = {
#         vmSize     = "Standard_DS3_v2"
#         vmPriority = "LowPriority"
#         scaleSettings = {
#           minNodeCount                = 0
#           maxNodeCount                = 4
#           nodeIdleTimeBeforeScaleDown = "PT120S"
#         }
#         subnet = {
#           id = var.subnet_id
#         }
#         enableNodePublicIp = false
#       }
#     }
#   })
#
#   tags = var.tags
#
#   depends_on = [azapi_resource.hub]
# }

# AI Foundry Hub에 Azure OpenAI 연결
resource "azapi_resource" "openai_connection" {
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-04-01"
  name      = "aoai-connection"
  parent_id = azapi_resource.hub.id

  body = jsonencode({
    properties = {
      category      = "AzureOpenAI"
      target        = var.openai_endpoint
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = var.openai_api_key
      }
      metadata = {
        ApiType    = "azure"       # 필수 속성 추가
        ApiVersion = "2024-02-15-preview"
        ResourceId = var.openai_resource_id
      }
    }
  })

  depends_on = [azapi_resource.hub]
}

# AI Search 연결 (RAG 패턴용)
resource "azapi_resource" "search_connection" {
  count     = var.ai_search_endpoint != "" ? 1 : 0
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-04-01"
  name      = "aisearch-connection"  # 이름 변경 (purge protection 충돌 해결)
  parent_id = azapi_resource.hub.id

  body = jsonencode({
    properties = {
      category      = "CognitiveSearch"
      target        = var.ai_search_endpoint
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = var.ai_search_api_key
      }
    }
  })

  depends_on = [azapi_resource.hub]
}
