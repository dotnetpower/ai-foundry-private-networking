output "capability_host_id" {
  description = "Capability Host ID"
  value       = azapi_resource.capability_host.id
}

output "capability_host_name" {
  description = "Capability Host 이름"
  value       = azapi_resource.capability_host.name
}

output "capability_host_properties" {
  description = "Capability Host 속성"
  value       = jsondecode(azapi_resource.capability_host.output)
}
