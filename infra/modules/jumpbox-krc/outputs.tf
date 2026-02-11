output "bastion_name" {
  description = "Azure Bastion 이름"
  value       = try(azurerm_bastion_host.main[0].name, null)
}

output "bastion_dns_name" {
  description = "Azure Bastion DNS 이름"
  value       = try(azurerm_bastion_host.main[0].dns_name, null)
}

output "windows_jumpbox_private_ip" {
  description = "Windows Jumpbox 프라이빗 IP"
  value       = azurerm_network_interface.windows.private_ip_address
}

output "linux_jumpbox_private_ip" {
  description = "Linux Jumpbox 프라이빗 IP"
  value       = azurerm_network_interface.linux.private_ip_address
}

output "windows_jumpbox_id" {
  description = "Windows Jumpbox VM ID"
  value       = azurerm_windows_virtual_machine.main.id
}

output "linux_jumpbox_id" {
  description = "Linux Jumpbox VM ID"
  value       = azurerm_linux_virtual_machine.main.id
}

output "windows_jumpbox_name" {
  description = "Windows Jumpbox VM 이름"
  value       = azurerm_windows_virtual_machine.main.name
}

output "linux_jumpbox_name" {
  description = "Linux Jumpbox VM 이름"
  value       = azurerm_linux_virtual_machine.main.name
}

output "jumpbox_vnet_id" {
  description = "Jumpbox VNet ID"
  value       = azurerm_virtual_network.jumpbox.id
}

output "jumpbox_subnet_id" {
  description = "Jumpbox Subnet ID"
  value       = azurerm_subnet.jumpbox.id
}

output "connection_instructions" {
  description = "Jumpbox 접속 방법"
  value       = <<-EOT
    # Jumpbox 접속 방법
    
    ## VM 정보
    - Windows: ${azurerm_windows_virtual_machine.main.name} (Private IP: ${azurerm_network_interface.windows.private_ip_address})
    - Linux: ${azurerm_linux_virtual_machine.main.name} (Private IP: ${azurerm_network_interface.linux.private_ip_address})
    
    ## 접속 방법
    VPN 또는 VNet Peering을 통해 Jumpbox에 접근하세요.
    Bastion이 활성화된 경우 Azure Portal에서 Bastion을 통해 연결할 수 있습니다.
    
    ## 설치된 개발 환경
    - Python 3.11 + 가상환경 (/opt/ai-dev-env)
    - Azure CLI
    - openai, azure-identity, azure-ai-projects 패키지
    - VS Code (Windows)
  EOT
}
