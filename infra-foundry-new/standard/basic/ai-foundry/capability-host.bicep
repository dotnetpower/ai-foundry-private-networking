// =============================================================================
// Project Capability Host - Agent 런타임을 VNet에 연결
// =============================================================================
// Based on: https://github.com/microsoft-foundry/foundry-samples
// PE 배포 완료 후 실행되어야 합니다 (main.bicep에서 dependsOn으로 보장)
// =============================================================================

@description('Foundry Account name')
param accountName string

@description('Foundry Project name')
param projectName string

@description('Storage connection name')
param storageConnectionName string

@description('Cosmos DB connection name')
param cosmosConnectionName string

@description('AI Search connection name')
param searchConnectionName string

// =============================================================================
// Existing Resources
// =============================================================================

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: projectName
  parent: account
}

// =============================================================================
// Project Capability Host
// =============================================================================

#disable-next-line BCP081
resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: 'default'
  parent: project
  properties: {
    capabilityHostKind: 'Agents'
    vectorStoreConnections: [
      searchConnectionName
    ]
    storageConnections: [
      storageConnectionName
    ]
    threadStorageConnections: [
      cosmosConnectionName
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

output capabilityHostName string = projectCapabilityHost.name
