# =============================================================================
# AI Services Account 출력
# =============================================================================
output "ai_account_name" {
  description = "AI Services 계정 이름"
  value       = local.account_name
}

output "ai_account_id" {
  description = "AI Services 계정 ID"
  value       = module.ai_account.account_id
}

output "ai_account_endpoint" {
  description = "AI Services 엔드포인트"
  value       = module.ai_account.account_endpoint
}

# =============================================================================
# AI Project 출력
# =============================================================================
output "project_name" {
  description = "AI Project 이름"
  value       = local.project_name
}

output "project_id" {
  description = "AI Project ID"
  value       = module.ai_project.project_id
}

output "project_principal_id" {
  description = "Project System Managed Identity Principal ID"
  value       = module.ai_project.project_principal_id
}

# =============================================================================
# Capability Host 출력
# =============================================================================
output "capability_host_name" {
  description = "Capability Host 이름"
  value       = module.capability_host.capability_host_name
}

output "capability_host_id" {
  description = "Capability Host ID"
  value       = module.capability_host.capability_host_id
}

# =============================================================================
# 네트워킹 출력
# =============================================================================
output "vnet_id" {
  description = "VNet ID"
  value       = local.vnet_id
}

output "agent_subnet_id" {
  description = "Agent 서브넷 ID"
  value       = local.agent_subnet_id
}

output "pe_subnet_id" {
  description = "Private Endpoint 서브넷 ID"
  value       = local.pe_subnet_id
}

# =============================================================================
# 의존 리소스 출력
# =============================================================================
output "storage_account_name" {
  description = "Storage Account 이름"
  value       = local.storage_name
}

output "cosmos_db_name" {
  description = "CosmosDB 계정 이름"
  value       = local.cosmos_db_name
}

output "ai_search_name" {
  description = "AI Search 서비스 이름"
  value       = local.ai_search_name
}

# =============================================================================
# 접근 정보
# =============================================================================
output "portal_link" {
  description = "Azure Portal에서 AI Foundry 열기"
  value       = "https://ai.azure.com"
}

output "resource_group_name" {
  description = "리소스 그룹 이름"
  value       = azurerm_resource_group.main.name
}
