// =============================================================================
// AI Foundry Module - Hosted Agent Configuration
// =============================================================================
// Foundry Account, Project, Model Deployments, Capability Host
// Ref: https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/hosted-agents
// =============================================================================

@description('Location for all resources')
param location string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Tags to apply to all resources')
param tags object = {}

@description('GPT model name')
param gptModelName string = 'gpt-4o'

@description('GPT model version')
param gptModelVersion string = '2024-11-20'

@description('GPT model capacity')
param gptModelCapacity int = 10

@description('Embedding model name')
param embeddingModelName string = 'text-embedding-ada-002'

@description('Embedding model version')
param embeddingModelVersion string = '2'

@description('Embedding model capacity')
param embeddingModelCapacity int = 10

// Short suffix for resource names
var shortSuffix = take(uniqueSuffix, 8)

// =============================================================================
// Foundry Account (kind: AIServices)
// Hosted Agent requires publicNetworkAccess: Enabled
// =============================================================================

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: 'cog-${shortSuffix}'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: 'cog-${shortSuffix}'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    allowProjectManagement: true
  }
}

// =============================================================================
// GPT Model Deployment
// =============================================================================

resource gptDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: foundryAccount
  name: gptModelName
  sku: {
    name: 'GlobalStandard'
    capacity: gptModelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: gptModelName
      version: gptModelVersion
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

// =============================================================================
// Embedding Model Deployment
// =============================================================================

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: foundryAccount
  name: embeddingModelName
  sku: {
    name: 'GlobalStandard'
    capacity: embeddingModelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModelName
      version: embeddingModelVersion
    }
  }
  dependsOn: [
    gptDeployment
  ]
}

// =============================================================================
// Foundry Project
// =============================================================================

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: foundryAccount
  name: 'proj-${shortSuffix}'
  location: location
  tags: tags
  kind: 'Project'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
  dependsOn: [
    embeddingDeployment
  ]
}

// =============================================================================
// Account-Level Capability Host (Hosted Agent 필수)
// enablePublicHostingEnvironment: true -> Hosted Agent 실행 허용
// API: 2025-10-01-preview
// =============================================================================

resource capabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-10-01-preview' = {
  parent: foundryAccount
  name: 'accountcaphost'
  properties: {
    capabilityHostKind: 'Agents'
    enablePublicHostingEnvironment: true
  }
  dependsOn: [
    foundryProject
  ]
}

// =============================================================================
// Outputs
// =============================================================================

output foundryAccountId string = foundryAccount.id
output foundryAccountName string = foundryAccount.name
output foundryAccountEndpoint string = foundryAccount.properties.endpoint
output foundryAccountPrincipalId string = foundryAccount.identity.principalId

output foundryProjectId string = foundryProject.id
output foundryProjectName string = foundryProject.name
output projectPrincipalId string = foundryProject.identity.principalId
