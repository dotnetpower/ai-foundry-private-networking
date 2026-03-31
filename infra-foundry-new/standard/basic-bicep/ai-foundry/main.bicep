// =============================================================================
// AI Foundry Module - Foundry Account, Project, Model Deployments
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Tags to apply to all resources')
param tags object = {}

@description('Agent subnet ID for capability host')
param agentSubnetId string

@description('Storage Account resource ID')
param storageAccountId string

@description('Storage Account name')
param storageAccountName string

@description('Cosmos DB Account resource ID')
param cosmosAccountId string

@description('Cosmos DB Account name')
param cosmosAccountName string

@description('AI Search Service resource ID')
param searchServiceId string

@description('AI Search Service name')
param searchServiceName string

// Short suffix for resource names
var shortSuffix = take(uniqueSuffix, 8)

// =============================================================================
// User Assigned Managed Identity
// =============================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${shortSuffix}'
  location: location
  tags: tags
}

// =============================================================================
// Foundry Account (kind: AIServices)
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
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    disableLocalAuth: false
    allowProjectManagement: true
    #disable-next-line BCP037
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetId
        useMicrosoftManagedNetwork: false
      }
    ]
  }
}

// =============================================================================
// GPT-4o Model Deployment
// =============================================================================

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: foundryAccount
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

// =============================================================================
// GPT-5.2 Model Deployment
// =============================================================================

resource gpt52Deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: foundryAccount
  name: 'gpt-5.2'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.2'
      version: '2025-12-11'
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  dependsOn: [
    gpt4oDeployment
  ]
}

// =============================================================================
// Text Embedding Model Deployment (RAG용 text-embedding-3-large)
// =============================================================================

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: foundryAccount
  name: 'text-embedding-3-large'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
    }
  }
  dependsOn: [
    gpt52Deployment
  ]
}

// =============================================================================
// Foundry Project (AI Hub in ML terms)
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
// Project Connections (Storage, Cosmos DB, AI Search)
// =============================================================================

resource storageConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: foundryProject
  name: 'storage-connection'
  properties: {
    category: 'AzureStorageAccount'
    target: 'https://${storageAccountName}.blob.${environment().suffixes.storage}'
    authType: 'AAD'
    metadata: {
      ApiType: 'azure'
      AccountName: storageAccountName
      ContainerName: 'agents-data'
      ResourceId: storageAccountId
    }
  }
}

resource cosmosConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: foundryProject
  name: 'cosmos-connection'
  properties: {
    category: 'CosmosDB'
    target: 'https://${cosmosAccountName}.documents.azure.com:443/'
    authType: 'AAD'
    metadata: {
      ApiType: 'azure'
      AccountName: cosmosAccountName
      DatabaseName: 'agentdb'
      ResourceId: cosmosAccountId
    }
  }
}

resource searchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: foundryProject
  name: 'search-connection'
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${searchServiceName}.search.windows.net'
    authType: 'AAD'
    metadata: {
      ApiType: 'azure'
      ResourceId: searchServiceId
    }
  }
}

resource ragStorageConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: foundryProject
  name: 'rag-storage-connection'
  properties: {
    category: 'AzureStorageAccount'
    target: 'https://${storageAccountName}.blob.${environment().suffixes.storage}'
    authType: 'AAD'
    metadata: {
      ApiType: 'azure'
      AccountName: storageAccountName
      ContainerName: 'rag-documents'
      ResourceId: storageAccountId
    }
  }
}

// =============================================================================
// RBAC Role Assignments (MS Official Sample Requirements)
// =============================================================================

// --- Storage ---
// Storage Blob Data Owner (Account + Project)
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
resource storageOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryAccount.id, storageBlobDataOwnerRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageProjectOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryProject.id, storageBlobDataOwnerRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor (Account + Project)
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource storageBlobContributorAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryAccount.id, storageBlobDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobContributorProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryProject.id, storageBlobDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Queue Data Contributor (Project - Azure Function tool 지원용)
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
resource storageQueueContributorProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryProject.id, storageQueueDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// --- Cosmos DB ---
// Cosmos DB Operator (관리 플레인, Account + Project)
var cosmosDbOperatorRoleId = '230815da-be43-4aae-9cb4-875f7bd000aa'
resource cosmosOperatorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosAccountId, foundryAccount.id, cosmosDbOperatorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cosmosDbOperatorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource cosmosProjectOperatorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosAccountId, foundryProject.id, cosmosDbOperatorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cosmosDbOperatorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Cosmos DB Built-in Data Contributor (데이터 플레인 RBAC, Account + Project)
var cosmosBuiltinDataContributorId = '00000000-0000-0000-0000-000000000002'

resource cosmosAccountRef 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

resource cosmosDataContributorAccount 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  name: guid(cosmosAccountId, foundryAccount.id, cosmosBuiltinDataContributorId)
  parent: cosmosAccountRef
  properties: {
    roleDefinitionId: '${cosmosAccountId}/sqlRoleDefinitions/${cosmosBuiltinDataContributorId}'
    principalId: foundryAccount.identity.principalId
    scope: cosmosAccountId
  }
}

resource cosmosDataContributorProject 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  name: guid(cosmosAccountId, foundryProject.id, cosmosBuiltinDataContributorId)
  parent: cosmosAccountRef
  properties: {
    roleDefinitionId: '${cosmosAccountId}/sqlRoleDefinitions/${cosmosBuiltinDataContributorId}'
    principalId: foundryProject.identity.principalId
    scope: cosmosAccountId
  }
}

// --- AI Search ---
// Search Index Data Contributor (Account + Project)
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
resource searchDataRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryAccount.id, searchIndexDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchProjectDataRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryProject.id, searchIndexDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Service Contributor (Account + Project)
var searchServiceContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
resource searchServiceRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryAccount.id, searchServiceContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchProjectServiceRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryProject.id, searchServiceContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// --- Cognitive Services ---
// Cognitive Services OpenAI Contributor (Project - 모델 호출 권한)
var cognitiveServicesOpenAIContributorRoleId = 'a001fd3d-188f-4b5d-821b-7da978bf7442'
resource cogServicesContributorProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, foundryProject.id, cognitiveServicesOpenAIContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output foundryAccountId string = foundryAccount.id
output foundryAccountName string = foundryAccount.name
output foundryAccountEndpoint string = foundryAccount.properties.endpoint

output foundryProjectId string = foundryProject.id
output foundryProjectName string = foundryProject.name

output managedIdentityId string = managedIdentity.id
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityClientId string = managedIdentity.properties.clientId

output systemAssignedPrincipalId string = foundryAccount.identity.principalId
output projectPrincipalId string = foundryProject.identity.principalId

// Connection names for Capability Host
output storageConnectionName string = storageConnection.name
output cosmosConnectionName string = cosmosConnection.name
output searchConnectionName string = searchConnection.name
