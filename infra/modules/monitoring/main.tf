# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-aifoundry"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-aifoundry"
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# Diagnostic Settings for Log Analytics (선택적)
# 추후 각 리소스의 진단 로그를 이 Workspace로 전송
