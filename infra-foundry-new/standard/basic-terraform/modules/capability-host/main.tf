# =============================================================================
# Capability Host Module - Agent Capability Host for Project (AzAPI)
# =============================================================================
# Based on: https://github.com/microsoft-foundry/foundry-samples
# =============================================================================

terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

variable "foundry_account_id" {
  type = string
}

variable "foundry_account_name" {
  type = string
}

variable "foundry_project_name" {
  type = string
}

variable "cosmos_connection_name" {
  type = string
}

variable "storage_connection_name" {
  type = string
}

variable "search_connection_name" {
  type = string
}

variable "capability_host_name" {
  type    = string
  default = "caphost-agent"
}

# =============================================================================
# Project Capability Host (Agents) — via AzAPI (preview API)
# =============================================================================

resource "azapi_resource" "capability_host" {
  type      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name      = var.capability_host_name
  parent_id = "${var.foundry_account_id}/projects/${var.foundry_project_name}"

  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind = "Agents"
      vectorStoreConnections = [
        var.search_connection_name
      ]
      storageConnections = [
        var.storage_connection_name
      ]
      threadStorageConnections = [
        var.cosmos_connection_name
      ]
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "capability_host_name" {
  value = azapi_resource.capability_host.name
}
