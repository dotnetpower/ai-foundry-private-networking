# ============================================================================
# Networking Module - Outputs
# ============================================================================

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "agent_subnet_id" {
  description = "ID of the Agent subnet"
  value       = azurerm_subnet.agent.id
}

output "agent_subnet_name" {
  description = "Name of the Agent subnet"
  value       = azurerm_subnet.agent.name
}

output "pe_subnet_id" {
  description = "ID of the Private Endpoint subnet"
  value       = azurerm_subnet.pe.id
}

output "pe_subnet_name" {
  description = "Name of the Private Endpoint subnet"
  value       = azurerm_subnet.pe.name
}
