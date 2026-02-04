# ============================================================================
# AI Services Module - Outputs
# ============================================================================

output "account_id" {
  description = "ID of the AI Services account"
  value       = azapi_resource.ai_services.id
}

output "account_name" {
  description = "Name of the AI Services account"
  value       = azapi_resource.ai_services.name
}

output "account_endpoint" {
  description = "Endpoint of the AI Services account"
  value       = jsondecode(azapi_resource.ai_services.output).properties.endpoint
}

output "account_principal_id" {
  description = "Principal ID of the AI Services account"
  value       = jsondecode(azapi_resource.ai_services.output).identity.principalId
}

output "model_deployment_id" {
  description = "ID of the model deployment"
  value       = azapi_resource.model_deployment.id
}
