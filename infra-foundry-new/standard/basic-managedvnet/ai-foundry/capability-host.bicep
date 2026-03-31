// =============================================================================
// Capability Host Module - Agent Capability Host for Project
// =============================================================================

@description('Foundry Account name')
param accountName string

@description('Project name')
param projectName string

@description('Cosmos DB connection name (for thread storage)')
param cosmosDBConnection string

@description('Storage connection name (for file storage)')
param azureStorageConnection string

@description('AI Search connection name (for vector store)')
param aiSearchConnection string

@description('Capability Host name')
param capabilityHostName string = 'caphost-agent'

// =============================================================================
// References
// =============================================================================

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: projectName
  parent: account
}

// =============================================================================
// Project Capability Host (Agents)
// =============================================================================

#disable-next-line BCP081
resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: capabilityHostName
  parent: project
  properties: {
    #disable-next-line BCP037
    capabilityHostKind: 'Agents'
    #disable-next-line BCP037
    vectorStoreConnections: [
      aiSearchConnection
    ]
    #disable-next-line BCP037
    storageConnections: [
      azureStorageConnection
    ]
    #disable-next-line BCP037
    threadStorageConnections: [
      cosmosDBConnection
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

output capabilityHostName string = projectCapabilityHost.name
