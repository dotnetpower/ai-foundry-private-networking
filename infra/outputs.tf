# =============================================================================
# Infrastructure Outputs
# =============================================================================

output "resource_group_name" {
  description = "리소스 그룹 이름"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "배포 리전"
  value       = azurerm_resource_group.main.location
}

# Networking
output "vnet_id" {
  description = "VNet ID"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "VNet 이름"
  value       = module.networking.vnet_name
}

# AI Foundry
output "ai_hub_id" {
  description = "AI Foundry Hub ID"
  value       = module.ai_foundry.ai_hub_id
}

output "ai_hub_name" {
  description = "AI Foundry Hub 이름"
  value       = module.ai_foundry.ai_hub_name
}

output "ai_project_id" {
  description = "AI Foundry Project ID"
  value       = module.ai_foundry.ai_project_id
}

# Cognitive Services
output "openai_endpoint" {
  description = "Azure OpenAI 엔드포인트"
  value       = module.cognitive_services.openai_endpoint
}

output "ai_search_endpoint" {
  description = "AI Search 엔드포인트"
  value       = module.cognitive_services.ai_search_endpoint
}

# Security
output "key_vault_name" {
  description = "Key Vault 이름"
  value       = module.security.key_vault_name
}

# Storage
output "storage_account_name" {
  description = "Storage Account 이름"
  value       = module.storage.storage_account_name
}

output "container_registry_name" {
  description = "Container Registry 이름"
  value       = module.storage.container_registry_name
}

# Jumpbox
output "jumpbox_private_ip" {
  description = "Linux Jumpbox 프라이빗 IP"
  value       = module.jumpbox.linux_jumpbox_private_ip
}

output "bastion_name" {
  description = "Azure Bastion 이름"
  value       = module.jumpbox.bastion_name
}

output "jumpbox_connection" {
  description = "Jumpbox 접속 방법"
  value       = module.jumpbox.connection_instructions
  sensitive   = true
}

# 배포 시간
output "deploy_duration" {
  description = "배포 시작 시간"
  value       = time_static.deploy_start.rfc3339
}
