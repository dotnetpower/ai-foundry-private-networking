output "account_id" {
  description = "AI Services 계정 ID"
  value       = azapi_resource.ai_account.id
}

output "account_name" {
  description = "AI Services 계정 이름"
  value       = azapi_resource.ai_account.name
}

output "account_endpoint" {
  description = "AI Services 엔드포인트"
  value       = jsondecode(azapi_resource.ai_account.output).properties.endpoint
}

output "account_principal_id" {
  description = "AI Services System Managed Identity Principal ID"
  value       = jsondecode(azapi_resource.ai_account.output).identity.principalId
}
