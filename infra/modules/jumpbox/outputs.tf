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

output "connection_instructions" {
  description = "Jumpbox 접속 방법"
  value       = <<-EOT
    # Jumpbox 접속 방법
    
    ## VM 정보
    - Linux: ${azurerm_linux_virtual_machine.main.name} (Private IP: ${azurerm_network_interface.linux.private_ip_address})
    
    ## Bastion을 통한 SSH 접속
    az network bastion ssh \
      --name bastion-aifoundry \
      --resource-group ${var.resource_group_name} \
      --target-resource-id ${azurerm_linux_virtual_machine.main.id} \
      --auth-type password \
      --username ${var.admin_username}
    
    ## 설치된 개발 환경
    - Python 3.11 + 가상환경 (/opt/ai-dev-env)
    - Azure CLI
    - openai, azure-identity, azure-ai-projects 패키지
  EOT
}
