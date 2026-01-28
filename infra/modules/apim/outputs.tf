output "apim_id" {
  description = "APIM 리소스 ID"
  value       = azurerm_api_management.main.id
}

output "apim_name" {
  description = "APIM 이름"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "APIM Gateway URL"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_developer_portal_url" {
  description = "APIM 개발자 포털 URL"
  value       = azurerm_api_management.main.developer_portal_url
}

output "apim_management_api_url" {
  description = "APIM 관리 API URL"
  value       = azurerm_api_management.main.management_api_url
}

output "apim_private_ip_addresses" {
  description = "APIM 프라이빗 IP 주소"
  value       = azurerm_api_management.main.private_ip_addresses
}

output "developer_subscription_primary_key" {
  description = "개발자 구독 Primary Key"
  value       = azurerm_api_management_subscription.developer.primary_key
  sensitive   = true
}

output "developer_subscription_secondary_key" {
  description = "개발자 구독 Secondary Key"
  value       = azurerm_api_management_subscription.developer.secondary_key
  sensitive   = true
}

output "production_subscription_primary_key" {
  description = "프로덕션 구독 Primary Key"
  value       = azurerm_api_management_subscription.production.primary_key
  sensitive   = true
}

output "admin_subscription_primary_key" {
  description = "관리자 구독 Primary Key"
  value       = azurerm_api_management_subscription.admin.primary_key
  sensitive   = true
}

output "openai_api_path" {
  description = "OpenAI API 경로"
  value       = "https://${azurerm_api_management.main.gateway_url}/openai"
}

output "api_usage_instructions" {
  description = "API 사용 방법"
  value       = <<-EOT
    # Azure OpenAI API 사용 방법
    
    ## 엔드포인트
    Gateway URL: ${azurerm_api_management.main.gateway_url}
    API Path: /openai
    
    ## API 호출 예시
    
    ### Chat Completions (GPT-4o)
    curl -X POST "${azurerm_api_management.main.gateway_url}/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-15-preview" \
      -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "messages": [
          {"role": "system", "content": "You are a helpful assistant."},
          {"role": "user", "content": "Hello!"}
        ],
        "max_tokens": 800,
        "temperature": 0.7
      }'
    
    ### Embeddings (text-embedding-ada-002)
    curl -X POST "${azurerm_api_management.main.gateway_url}/openai/deployments/text-embedding-ada-002/embeddings?api-version=2024-02-15-preview" \
      -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "input": "The quick brown fox jumps over the lazy dog"
      }'
    
    ## Rate Limits
    - 100 calls per minute
    - 10,000 calls per week
  EOT
}
