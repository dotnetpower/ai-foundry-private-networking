output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network 이름"
  value       = azurerm_virtual_network.main.name
}

output "ai_foundry_subnet_id" {
  description = "AI Foundry 서브넷 ID (Private Endpoints)"
  value       = azurerm_subnet.ai_foundry.id
}

output "jumpbox_subnet_id" {
  description = "Jumpbox 서브넷 ID"
  value       = azurerm_subnet.jumpbox.id
}

output "bastion_subnet_id" {
  description = "Azure Bastion 서브넷 ID"
  value       = azurerm_subnet.bastion.id
}

output "private_dns_zone_ids" {
  description = "Private DNS Zone ID 맵"
  value = {
    azureml     = azurerm_private_dns_zone.azureml.id
    notebooks   = azurerm_private_dns_zone.notebooks.id
    blob        = azurerm_private_dns_zone.blob.id
    file        = azurerm_private_dns_zone.file.id
    vault       = azurerm_private_dns_zone.vault.id
    cogservices = azurerm_private_dns_zone.cogservices.id
    openai      = azurerm_private_dns_zone.openai.id
    acr         = azurerm_private_dns_zone.acr.id
    search      = azurerm_private_dns_zone.search.id
  }
}
