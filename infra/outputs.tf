output "resource_group_name" {
  description = "리소스 그룹 이름"
  value       = azurerm_resource_group.main.name
}

output "deploy_date" {
  description = "배포 날짜"
  value       = local.deploy_date
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "Virtual Network 이름"
  value       = module.networking.vnet_name
}

output "ai_foundry_subnet_id" {
  description = "AI Foundry 서브넷 ID"
  value       = module.networking.ai_foundry_subnet_id
}

output "jumpbox_subnet_id" {
  description = "Jumpbox 서브넷 ID"
  value       = module.networking.jumpbox_subnet_id
}

output "storage_account_name" {
  description = "Storage Account 이름"
  value       = module.storage.storage_account_name
}

output "key_vault_name" {
  description = "Key Vault 이름"
  value       = module.security.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.security.key_vault_uri
}

output "ai_hub_id" {
  description = "AI Hub (ML Workspace) ID"
  value       = module.ai_foundry.ai_hub_id
}

output "ai_hub_name" {
  description = "AI Hub (ML Workspace) 이름"
  value       = module.ai_foundry.ai_hub_name
}

output "application_insights_connection_string" {
  description = "Application Insights 연결 문자열"
  value       = module.monitoring.application_insights_connection_string
  sensitive   = true
}

# Jumpbox 출력 (East US - 주석 처리됨)
# output "jumpbox_windows_private_ip" {
#   description = "Windows Jumpbox 프라이빗 IP"
#   value       = module.jumpbox.windows_jumpbox_private_ip
# }

# Jumpbox 출력 (Korea Central with Azure Bastion)
output "bastion_name" {
  description = "Azure Bastion 이름"
  value       = module.jumpbox_krc.bastion_name
}

output "jumpbox_windows_private_ip" {
  description = "Windows Jumpbox 프라이빗 IP (Korea Central)"
  value       = module.jumpbox_krc.windows_jumpbox_private_ip
}

output "jumpbox_linux_private_ip" {
  description = "Linux Jumpbox 프라이빗 IP (Korea Central)"
  value       = module.jumpbox_krc.linux_jumpbox_private_ip
}

output "jumpbox_connection_instructions" {
  description = "Jumpbox 접속 방법 안내"
  value       = module.jumpbox_krc.connection_instructions
  sensitive   = true
}

output "jumpbox_location" {
  description = "Jumpbox 배포 리전"
  value       = "koreacentral"
}

# API Management 출력 (APIM 모듈 주석 해제 후 활성화)
# output "apim_gateway_url" {
#   description = "API Management Gateway URL"
#   value       = module.apim.apim_gateway_url
# }

# output "apim_private_ip_addresses" {
#   description = "API Management 프라이빗 IP 주소들"
#   value       = module.apim.apim_private_ip_addresses
# }

# output "apim_developer_subscription_primary_key" {
#   description = "API Management 개발자 구독 Primary Key"
#   value       = module.apim.developer_subscription_primary_key
#   sensitive   = true
# }

# output "apim_developer_subscription_secondary_key" {
#   description = "API Management 개발자 구독 Secondary Key"
#   value       = module.apim.developer_subscription_secondary_key
#   sensitive   = true
# }

# output "apim_openai_api_path" {
#   description = "APIM을 통한 OpenAI API 경로"
#   value       = module.apim.openai_api_path
# }

# output "apim_api_usage_instructions" {
#   description = "API 사용 방법 안내"
#   value       = module.apim.api_usage_instructions
# }
