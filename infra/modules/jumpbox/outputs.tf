output "bastion_name" {
  description = "Azure Bastion 이름"
  value       = try(azurerm_bastion_host.main[0].name, null)
}

output "bastion_dns_name" {
  description = "Azure Bastion DNS 이름"
  value       = try(azurerm_bastion_host.main[0].dns_name, null)
}

output "linux_jumpbox_private_ip" {
  description = "Linux Jumpbox 프라이빗 IP"
  value       = azurerm_network_interface.linux.private_ip_address
}

output "linux_jumpbox_id" {
  description = "Linux Jumpbox VM ID"
  value       = azurerm_linux_virtual_machine.main.id
}

output "linux_jumpbox_name" {
  description = "Linux Jumpbox VM 이름"
  value       = azurerm_linux_virtual_machine.main.name
}

output "windows_jumpbox_private_ip" {
  description = "Windows Jumpbox 프라이빗 IP"
  value       = try(azurerm_network_interface.windows[0].private_ip_address, null)
}

output "windows_jumpbox_id" {
  description = "Windows Jumpbox VM ID"
  value       = try(azurerm_windows_virtual_machine.main[0].id, null)
}

output "windows_jumpbox_name" {
  description = "Windows Jumpbox VM 이름"
  value       = try(azurerm_windows_virtual_machine.main[0].name, null)
}

output "connection_instructions" {
  description = "Jumpbox 접속 방법"
  value       = <<-EOT
    # Jumpbox 접속 방법
    
    ## VM 정보
    - Linux: ${azurerm_linux_virtual_machine.main.name} (Private IP: ${azurerm_network_interface.linux.private_ip_address})
    ${try("- Windows: ${azurerm_windows_virtual_machine.main[0].name} (Private IP: ${azurerm_network_interface.windows[0].private_ip_address})", "")}
    
    ## Bastion을 통한 SSH 접속 (Linux)
    az network bastion ssh \
      --name bastion-aifoundry \
      --resource-group ${var.resource_group_name} \
      --target-resource-id ${azurerm_linux_virtual_machine.main.id} \
      --auth-type password \
      --username ${var.admin_username}
    
    ## Bastion을 통한 RDP 접속 (Windows)
    az network bastion rdp \
      --name bastion-aifoundry \
      --resource-group ${var.resource_group_name} \
      --target-resource-id <Windows VM Resource ID>
  EOT
}
