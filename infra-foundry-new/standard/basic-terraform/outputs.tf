# =============================================================================
# Outputs
# =============================================================================

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "resource_group_id" {
  value = azurerm_resource_group.main.id
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "vnet_name" {
  value = module.networking.vnet_name
}

output "hub_spoke_enabled" {
  value = var.hub_vnet_id != ""
}

output "foundry_account_name" {
  value = module.ai_foundry.foundry_account_name
}

output "foundry_account_endpoint" {
  value = module.ai_foundry.foundry_account_endpoint
}

output "foundry_project_name" {
  value = module.ai_foundry.foundry_project_name
}

output "storage_account_name" {
  value = module.dependent_resources.storage_account_name
}

output "cosmos_account_name" {
  value = module.dependent_resources.cosmos_account_name
}

output "search_service_name" {
  value = module.dependent_resources.search_service_name
}

output "jumpbox_private_ip" {
  value = var.deploy_jumpbox ? module.jumpbox[0].private_ip : "not-deployed"
}

output "jumpbox_public_ip" {
  value = var.deploy_jumpbox ? module.jumpbox[0].public_ip : "not-deployed"
}
