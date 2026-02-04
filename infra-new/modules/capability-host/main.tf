terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

# =============================================================================
# Capability Host (Microsoft.CognitiveServices/accounts/projects/capabilityHosts)
# =============================================================================

# 중요: Capability Host는 다음 조건이 충족된 후에만 생성 가능
# 1. Project의 Connections (CosmosDB, Storage, Search)가 생성됨
# 2. Project SMI에 필요한 RBAC 역할이 할당됨
# 3. Private Endpoints가 Succeeded 상태
# 4. Agent 서브넷에 Microsoft.App/environments 위임이 설정됨

resource "azapi_resource" "capability_host" {
  type      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name      = var.caphost_name
  parent_id = "${var.resource_group_id}/providers/Microsoft.CognitiveServices/accounts/${var.account_name}/projects/${var.project_name}"

  # azapi 스키마 검증 비활성화 (preview API 사용)
  schema_validation_enabled = false

  body = {
    properties = {
      # Capability Host 종류 (Agent용)
      capabilityHostKind = "Agents"

      # Vector Store Connections (AI Search)
      vectorStoreConnections = [var.ai_search_connection]

      # Storage Connections (File Storage)
      storageConnections = [var.storage_connection]

      # Thread Storage Connections (CosmosDB)
      threadStorageConnections = [var.cosmos_db_connection]
    }
  }

  response_export_values = ["id", "name", "properties"]

  # 생성 시간이 오래 걸릴 수 있음 (최대 20분)
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
