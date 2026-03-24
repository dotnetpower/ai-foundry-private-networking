// =============================================================================
// Main Bicep Template - Azure Foundry Hosted Agent
// =============================================================================
// Based on: https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/hosted-agents
// Hosted Agent: 컨테이너화된 에이전트 코드를 Foundry Agent Service에서 관리형으로 실행
// =============================================================================

targetScope = 'subscription'

// =============================================================================
// Parameters
// =============================================================================

@description('Location for all resources')
param location string = 'swedencentral'

@description('Resource group name')
param resourceGroupName string = 'rg-aifoundry-hosted'

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environmentName string = 'dev'

@description('ACR SKU (Basic, Standard, Premium)')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

@description('GPT model name to deploy')
param gptModelName string = 'gpt-4o'

@description('GPT model version')
param gptModelVersion string = '2024-11-20'

@description('GPT model deployment capacity (TPM in thousands)')
param gptModelCapacity int = 10

@description('Embedding model name to deploy')
param embeddingModelName string = 'text-embedding-ada-002'

@description('Embedding model version')
param embeddingModelVersion string = '2'

@description('Embedding model deployment capacity')
param embeddingModelCapacity int = 10

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  Project: 'AI-Foundry-Hosted-Agent'
  ManagedBy: 'Bicep'
}

// =============================================================================
// Resource Group
// =============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// Monitoring Module (Log Analytics + Application Insights)
// =============================================================================

module monitoring 'monitoring/main.bicep' = {
  scope: rg
  name: 'monitoring-deployment'
  params: {
    location: location
    tags: tags
  }
}

// =============================================================================
// AI Foundry Module (Account, Project, Models, Capability Host)
// =============================================================================

module aiFoundry 'ai-foundry/main.bicep' = {
  scope: rg
  name: 'ai-foundry-deployment'
  params: {
    location: location
    gptModelName: gptModelName
    gptModelVersion: gptModelVersion
    gptModelCapacity: gptModelCapacity
    embeddingModelName: embeddingModelName
    embeddingModelVersion: embeddingModelVersion
    embeddingModelCapacity: embeddingModelCapacity
    tags: tags
  }
}

// =============================================================================
// Container Registry Module (ACR for Hosted Agent images)
// =============================================================================

module containerRegistry 'container-registry/main.bicep' = {
  scope: rg
  name: 'container-registry-deployment'
  params: {
    location: location
    acrSku: acrSku
    projectPrincipalId: aiFoundry.outputs.projectPrincipalId
    tags: tags
  }
}

// =============================================================================
// Outputs
// =============================================================================

output resourceGroupName string = rg.name

output foundryAccountName string = aiFoundry.outputs.foundryAccountName
output foundryAccountEndpoint string = aiFoundry.outputs.foundryAccountEndpoint
output foundryProjectName string = aiFoundry.outputs.foundryProjectName
output foundryProjectId string = aiFoundry.outputs.foundryProjectId

output acrName string = containerRegistry.outputs.acrName
output acrLoginServer string = containerRegistry.outputs.acrLoginServer

output appInsightsName string = monitoring.outputs.appInsightsName
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
