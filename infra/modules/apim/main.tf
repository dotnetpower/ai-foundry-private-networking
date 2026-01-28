# API Management Service
resource "azurerm_api_management" "main" {
  name                = "apim-aifoundry-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = var.subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  # 개발자 포털 활성화 설정
  sign_up {
    enabled = true
    terms_of_service {
      enabled          = true
      consent_required = true
      text             = "By using this API service, you agree to abide by our terms of service and acceptable use policies."
    }
  }

  sign_in {
    enabled = true
  }

  tags = var.tags
}

# Random suffix for APIM (전역 고유성 보장)
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Azure OpenAI Backend
resource "azurerm_api_management_backend" "openai" {
  name                = "openai-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${var.openai_endpoint}"
  description         = "Azure OpenAI Service Backend"

  credentials {
    header = {
      "api-key" = var.openai_api_key
    }
  }
}

# Azure OpenAI API
resource "azurerm_api_management_api" "openai" {
  name                  = "azure-openai-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Azure OpenAI API"
  path                  = "openai"
  protocols             = ["https"]
  service_url           = "https://${var.openai_endpoint}"
  subscription_required = true

  subscription_key_parameter_names {
    header = "Ocp-Apim-Subscription-Key"
    query  = "subscription-key"
  }
}

# Chat Completions Operation
resource "azurerm_api_management_api_operation" "chat_completions" {
  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Create Chat Completion"
  method              = "POST"
  url_template        = "/deployments/{deployment-id}/chat/completions"
  description         = "Creates a chat completion for the provided messages"

  template_parameter {
    name     = "deployment-id"
    required = true
    type     = "string"
  }

  request {
    description = "Chat completion request"

    representation {
      content_type = "application/json"
      example {
        name = "default"
        value = jsonencode({
          messages = [
            {
              role    = "system"
              content = "You are a helpful assistant."
            },
            {
              role    = "user"
              content = "Hello!"
            }
          ]
          max_tokens  = 800
          temperature = 0.7
        })
      }
    }
  }

  response {
    status_code = 200
    description = "Success"
    representation {
      content_type = "application/json"
    }
  }
}

# Embeddings Operation
resource "azurerm_api_management_api_operation" "embeddings" {
  operation_id        = "embeddings"
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Create Embeddings"
  method              = "POST"
  url_template        = "/deployments/{deployment-id}/embeddings"
  description         = "Creates an embedding vector representing the input text"

  template_parameter {
    name     = "deployment-id"
    required = true
    type     = "string"
  }

  request {
    description = "Embedding request"

    representation {
      content_type = "application/json"
      example {
        name = "default"
        value = jsonencode({
          input = "The quick brown fox jumps over the lazy dog"
        })
      }
    }
  }

  response {
    status_code = 200
    description = "Success"
    representation {
      content_type = "application/json"
    }
  }
}

# API Policy - Rate Limiting & Backend Routing
resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="openai-backend" />
    <rate-limit calls="100" renewal-period="60" />
    <quota calls="10000" renewal-period="604800" />
    <set-header name="api-key" exists-action="override">
      <value>@(context.Api.Credentials.Header.GetValueOrDefault("Ocp-Apim-Subscription-Key",""))</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML

  depends_on = [
    azurerm_api_management_backend.openai
  ]
}

# Product - Developer Access
resource "azurerm_api_management_product" "developers" {
  product_id            = "developer-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "Developer Product"
  description           = "Access to Azure OpenAI API for developers"
  subscription_required = true
  approval_required     = false
  published             = true
  subscriptions_limit   = 10
}

# Product - Production (승인 필요)
resource "azurerm_api_management_product" "production" {
  product_id            = "production-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "Production Product"
  description           = "Production access to Azure OpenAI API with higher rate limits"
  subscription_required = true
  approval_required     = true
  published             = true
  subscriptions_limit   = 5
}

# Product - Unlimited (관리자 전용)
resource "azurerm_api_management_product" "unlimited" {
  product_id            = "unlimited-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "Unlimited Product"
  description           = "Unlimited access to Azure OpenAI API for administrators"
  subscription_required = true
  approval_required     = true
  published             = true
  subscriptions_limit   = 3
}

# User Group - Developers
resource "azurerm_api_management_group" "developers" {
  name                = "developers"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  display_name        = "Developers"
  description         = "개발자 그룹 - 개발 및 테스트 환경 접근 권한"
  type                = "custom"
}

# User Group - AI Engineers
resource "azurerm_api_management_group" "ai_engineers" {
  name                = "ai-engineers"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  display_name        = "AI Engineers"
  description         = "AI 엔지니어 그룹 - 에이전트 개발 및 프로덕션 접근 권한"
  type                = "custom"
}

# User Group - Administrators
resource "azurerm_api_management_group" "administrators" {
  name                = "ai-administrators"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  display_name        = "AI Administrators"
  description         = "관리자 그룹 - 모든 리소스 및 무제한 접근 권한"
  type                = "custom"
}

# Product-Group 연결: Developer Product → Developers Group
resource "azurerm_api_management_product_group" "dev_developers" {
  product_id          = azurerm_api_management_product.developers.product_id
  group_name          = azurerm_api_management_group.developers.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# Product-Group 연결: Production Product → AI Engineers Group
resource "azurerm_api_management_product_group" "prod_engineers" {
  product_id          = azurerm_api_management_product.production.product_id
  group_name          = azurerm_api_management_group.ai_engineers.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# Product-Group 연결: Unlimited Product → Administrators Group
resource "azurerm_api_management_product_group" "unlimited_admins" {
  product_id          = azurerm_api_management_product.unlimited.product_id
  group_name          = azurerm_api_management_group.administrators.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# Link API to Product
resource "azurerm_api_management_product_api" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  product_id          = azurerm_api_management_product.developers.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# Link API to Production Product
resource "azurerm_api_management_product_api" "openai_production" {
  api_name            = azurerm_api_management_api.openai.name
  product_id          = azurerm_api_management_product.production.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# Link API to Unlimited Product
resource "azurerm_api_management_product_api" "openai_unlimited" {
  api_name            = azurerm_api_management_api.openai.name
  product_id          = azurerm_api_management_product.unlimited.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# Developer Product Policy (Rate Limiting)
resource "azurerm_api_management_product_policy" "developers" {
  product_id          = azurerm_api_management_product.developers.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit calls="100" renewal-period="60" />
    <quota calls="5000" renewal-period="604800" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# Production Product Policy (Higher Rate Limits)
resource "azurerm_api_management_product_policy" "production" {
  product_id          = azurerm_api_management_product.production.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit calls="500" renewal-period="60" />
    <quota calls="50000" renewal-period="604800" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# Unlimited Product Policy (No Rate Limits)
resource "azurerm_api_management_product_policy" "unlimited" {
  product_id          = azurerm_api_management_product.unlimited.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <!-- No rate limiting for administrators -->
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# Subscription for Developers
resource "azurerm_api_management_subscription" "developer" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Developer Subscription"
  product_id          = azurerm_api_management_product.developers.id
  state               = "active"
  allow_tracing       = true
}

# Subscription for Production
resource "azurerm_api_management_subscription" "production" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Production Subscription"
  product_id          = azurerm_api_management_product.production.id
  state               = "active"
  allow_tracing       = false
}

# Subscription for Administrators
resource "azurerm_api_management_subscription" "admin" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Administrator Subscription"
  product_id          = azurerm_api_management_product.unlimited.id
  state               = "active"
  allow_tracing       = true
}

# Private Endpoint for APIM
resource "azurerm_private_endpoint" "apim" {
  name                = "pe-apim"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-apim"
    private_connection_resource_id = azurerm_api_management.main.id
    is_manual_connection           = false
    subresource_names              = ["Gateway"]
  }

  private_dns_zone_group {
    name                 = "pdnsz-group-apim"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

# Named Value - OpenAI Key (Secure)
resource "azurerm_api_management_named_value" "openai_key" {
  name                = "openai-api-key"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  display_name        = "openai-api-key"
  secret              = true
  value               = var.openai_api_key
}

# Logger - Application Insights Integration
resource "azurerm_api_management_logger" "appinsights" {
  name                = "appinsights-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  resource_id         = var.application_insights_id

  application_insights {
    instrumentation_key = var.application_insights_instrumentation_key
  }
}

# Diagnostic Settings
resource "azurerm_api_management_api_diagnostic" "openai" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = azurerm_api_management.main.name
  api_name                 = azurerm_api_management_api.openai.name
  api_management_logger_id = azurerm_api_management_logger.appinsights.id

  sampling_percentage       = 100.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = 1024
    headers_to_log = ["Content-Type", "User-Agent"]
  }

  frontend_response {
    body_bytes     = 1024
    headers_to_log = ["Content-Type"]
  }

  backend_request {
    body_bytes     = 1024
    headers_to_log = ["Content-Type"]
  }

  backend_response {
    body_bytes     = 1024
    headers_to_log = ["Content-Type"]
  }
}
