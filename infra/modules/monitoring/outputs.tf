output "application_insights_id" {
  description = "Application Insights ID"
  value       = azurerm_application_insights.main.id
}

output "application_insights_name" {
  description = "Application Insights 이름"
  value       = azurerm_application_insights.main.name
}

output "application_insights_connection_string" {
  description = "Application Insights 연결 문자열"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "Application Insights Instrumentation Key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace 이름"
  value       = azurerm_log_analytics_workspace.main.name
}
