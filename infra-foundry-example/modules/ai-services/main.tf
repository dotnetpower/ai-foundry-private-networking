# ============================================================================
# AI Services Module - AI Services Account with Model Deployment
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

# ============================================================================
# AI Services Account (Cognitive Services - AIServices kind)
# ============================================================================

resource "azapi_resource" "ai_services" {
  type      = "Microsoft.CognitiveServices/accounts@2025-04-01-preview"
  name      = var.account_name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = var.account_name
      publicNetworkAccess    = "Disabled"
      disableLocalAuth       = false
      networkAcls = {
        defaultAction       = "Deny"
        virtualNetworkRules = []
        ipRules             = []
        bypass              = "AzureServices"
      }
      networkInjections = var.enable_network_injection ? [
        {
          scenario                   = "agent"
          subnetArmId                = var.agent_subnet_id
          useMicrosoftManagedNetwork = false
        }
      ] : null
    }
  }

  tags = var.tags

  response_export_values = ["properties.endpoint", "identity.principalId"]
}

data "azurerm_client_config" "current" {}

# ============================================================================
# Model Deployment
# ============================================================================

resource "azapi_resource" "model_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview"
  name      = var.model_name
  parent_id = azapi_resource.ai_services.id

  body = {
    sku = {
      capacity = var.model_capacity
      name     = var.model_sku_name
    }
    properties = {
      model = {
        name    = var.model_name
        format  = var.model_format
        version = var.model_version
      }
    }
  }

  depends_on = [azapi_resource.ai_services]
}
