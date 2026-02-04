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

# =============================================================================
# AI Services Account (Microsoft.CognitiveServices/accounts)
# =============================================================================

resource "azapi_resource" "ai_account" {
  type      = "Microsoft.CognitiveServices/accounts@2025-04-01-preview"
  name      = var.account_name
  location  = var.location
  parent_id = var.resource_group_id

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      # 필수: 프로젝트 관리 허용
      allowProjectManagement = true

      # 커스텀 서브도메인 (필수 - Private Endpoint용)
      customSubDomainName = var.account_name

      # 네트워크 설정
      networkAcls = {
        defaultAction = "Deny"
        bypass        = "AzureServices"
        ipRules       = []
        virtualNetworkRules = []
      }

      publicNetworkAccess = "Disabled"

      # Agent 서브넷에 네트워크 인젝션 (Capability Host용 필수)
      networkInjections = [
        {
          scenario                  = "agent"
          subnetArmId               = var.agent_subnet_id
          useMicrosoftManagedNetwork = false
        }
      ]

      # AAD 인증만 사용 (disableLocalAuth 정책이 있으면 이 값은 무시됨)
      disableLocalAuth = false
    }
  }

  response_export_values = ["properties.endpoint", "id", "identity"]

  tags = var.tags
}

# AI Account Private Endpoint
resource "azurerm_private_endpoint" "ai_account" {
  name                = "pe-aiservices-${var.account_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-aiservices"
    private_connection_resource_id = azapi_resource.ai_account.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name = "pdnsz-group-aiservices"
    private_dns_zone_ids = [
      var.private_dns_zone_ids.cognitiveservices,
      var.private_dns_zone_ids.openai,
      var.private_dns_zone_ids.services_ai
    ]
  }

  depends_on = [azapi_resource.ai_account]
}

# =============================================================================
# Model Deployment
# =============================================================================

resource "azapi_resource" "model_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview"
  name      = var.model_name
  parent_id = azapi_resource.ai_account.id

  body = {
    sku = {
      name     = var.model_sku_name
      capacity = var.model_capacity
    }
    properties = {
      model = {
        name    = var.model_name
        format  = var.model_format
        version = var.model_version
      }
    }
  }

  depends_on = [azapi_resource.ai_account]
}
