output "bastion_name" {
  description = "Azure Bastion 이름"
  value       = azurerm_bastion_host.main.name
}

output "bastion_dns_name" {
  description = "Azure Bastion DNS 이름"
  value       = azurerm_bastion_host.main.dns_name
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
    # Azure Bastion을 통한 Jumpbox 접속 방법
    
    ## 1. Azure Portal에서 접속
    1. Azure Portal → Virtual Machines
    2. vm-jb-win-krc 또는 vm-jumpbox-linux-krc 선택
    3. Connect → Bastion 클릭
    4. 사용자명/비밀번호 입력 후 연결
    
    ## 2. Azure CLI로 접속 (Native Client)
    
    ### Windows Jumpbox (RDP)
    az network bastion rdp \
      --name ${azurerm_bastion_host.main.name} \
      --resource-group ${var.resource_group_name} \
      --target-resource-id ${azurerm_windows_virtual_machine.main.id}
    
    ### Linux Jumpbox (SSH)
    az network bastion ssh \
      --name ${azurerm_bastion_host.main.name} \
      --resource-group ${var.resource_group_name} \
      --target-resource-id ${azurerm_linux_virtual_machine.main.id} \
      --auth-type password \
      --username ${var.admin_username}
    
    ## 3. 설치된 개발 환경
    - Python 3.11 + 가상환경 (/opt/ai-dev-env)
    - Azure CLI
    - openai, azure-identity, azure-ai-projects 패키지
    - VS Code (Windows)
  EOT
}
