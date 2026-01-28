output "openai_id" {
  description = "Azure OpenAI Service ID"
  value       = azurerm_cognitive_account.openai.id
}

output "openai_name" {
  description = "Azure OpenAI Service 이름"
  value       = azurerm_cognitive_account.openai.name
}

output "openai_endpoint" {
  description = "Azure OpenAI Service 엔드포인트"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "openai_api_key" {
  description = "Azure OpenAI Service Primary API Key"
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}

output "openai_hostname" {
  description = "Azure OpenAI Service 호스트명 (APIM 백엔드용)"
  value       = replace(azurerm_cognitive_account.openai.endpoint, "https://", "")
}

output "ai_search_id" {
  description = "Azure AI Search ID"
  value       = azurerm_search_service.main.id
}

output "ai_search_name" {
  description = "Azure AI Search 이름"
  value       = azurerm_search_service.main.name
}

output "ai_search_endpoint" {
  description = "Azure AI Search 엔드포인트"
  value       = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "ai_search_primary_key" {
  description = "Azure AI Search Primary Key"
  value       = azurerm_search_service.main.primary_key
  sensitive   = true
}
