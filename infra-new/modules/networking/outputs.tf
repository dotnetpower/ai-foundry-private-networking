output "vnet_id" {
  description = "VNet ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "VNet 이름"
  value       = azurerm_virtual_network.main.name
}

output "agent_subnet_id" {
  description = "Agent 서브넷 ID"
  value       = azurerm_subnet.agent.id
}

output "agent_subnet_name" {
  description = "Agent 서브넷 이름"
  value       = azurerm_subnet.agent.name
}

output "pe_subnet_id" {
  description = "Private Endpoint 서브넷 ID"
  value       = azurerm_subnet.pe.id
}

output "pe_subnet_name" {
  description = "Private Endpoint 서브넷 이름"
  value       = azurerm_subnet.pe.name
}
