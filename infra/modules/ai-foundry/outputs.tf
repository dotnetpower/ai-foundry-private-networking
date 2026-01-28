output "ai_hub_id" {
  description = "AI Foundry Hub ID"
  value       = azapi_resource.hub.id
}

output "ai_hub_name" {
  description = "AI Foundry Hub 이름"
  value       = azapi_resource.hub.name
}

output "ai_project_id" {
  description = "AI Foundry Project ID"
  value       = azapi_resource.project.id
}

output "ai_project_name" {
  description = "AI Foundry Project 이름"
  value       = azapi_resource.project.name
}

output "openai_connection_id" {
  description = "OpenAI 연결 ID"
  value       = azapi_resource.openai_connection.id
}

output "search_connection_id" {
  description = "AI Search 연결 ID"
  value       = length(azapi_resource.search_connection) > 0 ? azapi_resource.search_connection[0].id : null
}

# Compute Cluster 주석 처리됨 (AI Foundry에서 AmlCompute 지원 안됨)
# output "compute_cluster_id" {
#   description = "Compute Cluster ID"
#   value       = azapi_resource.compute_cluster.id
# }
