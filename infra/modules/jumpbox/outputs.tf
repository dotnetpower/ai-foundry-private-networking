output "windows_jumpbox_private_ip" {
  description = "Windows Jumpbox 프라이빗 IP"
  value       = azurerm_network_interface.windows.private_ip_address
}

output "windows_jumpbox_public_ip" {
  description = "Windows Jumpbox 퍼블릭 IP"
  value       = azurerm_public_ip.windows.ip_address
}

output "linux_jumpbox_private_ip" {
  description = "Linux Jumpbox 프라이빗 IP"
  value       = azurerm_network_interface.linux.private_ip_address
}

output "linux_jumpbox_public_ip" {
  description = "Linux Jumpbox 퍼블릭 IP"
  value       = azurerm_public_ip.linux.ip_address
}

output "windows_jumpbox_name" {
  description = "Windows Jumpbox VM 이름"
  value       = azurerm_windows_virtual_machine.main.name
}

output "linux_jumpbox_name" {
  description = "Linux Jumpbox VM 이름"
  value       = azurerm_linux_virtual_machine.main.name
}
