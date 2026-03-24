// =============================================================================
// Korea Central Test Environment Parameters - Hosted Agent
// =============================================================================
// Usage: az deployment sub create --location koreacentral --template-file main.bicep --parameters parameters/kc-test.bicepparam
// =============================================================================

using '../main.bicep'

param location = 'koreacentral'
param resourceGroupName = 'rg-aifoundry-hosted-kc'
param environmentName = 'dev'

// Container Registry
param acrSku = 'Basic'

// Model Deployments
param gptModelName = 'gpt-4o'
param gptModelVersion = '2024-11-20'
param gptModelCapacity = 10

param embeddingModelName = 'text-embedding-ada-002'
param embeddingModelVersion = '2'
param embeddingModelCapacity = 10

param tags = {
  Environment: 'dev'
  Project: 'AI-Foundry-Hosted-Agent'
  ManagedBy: 'Bicep'
}
