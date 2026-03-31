// =============================================================================
// AI Foundry Module - Managed VNet (Preview)
// =============================================================================
// useMicrosoftManagedNetwork: true → Azure가 VNet/PE/DNS를 자동 관리
// ⚠️ E2E Private 불가: Account publicNetworkAccess 는 Enabled 필수
//    (Agent Service가 Account 컨트롤 플레인을 통해 동작)
// =============================================================================

@description('Location for all resources')
param location string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Tags to apply to all resources')
param tags object = {}

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
// Foundry Account (kind: AIServices, Managed VNet)
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
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false
    allowProjectManagement: true
    #disable-next-line BCP037
    networkInjections: [
      {
        scenario: 'agent'
        useMicrosoftManagedNetwork: true
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
// Text Embedding Model Deployment
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
    gpt4oDeployment
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
  dependsOn: [
    storageConnection
  ]
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
  dependsOn: [
    cosmosConnection
  ]
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

// =============================================================================
// RBAC Role Assignments
// =============================================================================

// --- Storage ---
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'

resource storageOwnerAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryAccount.id, storageBlobDataOwnerRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageOwnerProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryProject.id, storageBlobDataOwnerRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageContributorAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryAccount.id, storageBlobDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageContributorProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryProject.id, storageBlobDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageQueueProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryProject.id, storageQueueDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// --- Cosmos DB ---
var cosmosDbOperatorRoleId = '230815da-be43-4aae-9cb4-875f7bd000aa'
var cosmosBuiltinDataContributorId = '00000000-0000-0000-0000-000000000002'

resource cosmosOperatorAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosAccountId, foundryAccount.id, cosmosDbOperatorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cosmosDbOperatorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource cosmosOperatorProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosAccountId, foundryProject.id, cosmosDbOperatorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cosmosDbOperatorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource cosmosAccountRef 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

resource cosmosDataAccount 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  name: guid(cosmosAccountId, foundryAccount.id, cosmosBuiltinDataContributorId)
  parent: cosmosAccountRef
  properties: {
    roleDefinitionId: '${cosmosAccountId}/sqlRoleDefinitions/${cosmosBuiltinDataContributorId}'
    principalId: foundryAccount.identity.principalId
    scope: cosmosAccountId
  }
}

resource cosmosDataProject 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  name: guid(cosmosAccountId, foundryProject.id, cosmosBuiltinDataContributorId)
  parent: cosmosAccountRef
  properties: {
    roleDefinitionId: '${cosmosAccountId}/sqlRoleDefinitions/${cosmosBuiltinDataContributorId}'
    principalId: foundryProject.identity.principalId
    scope: cosmosAccountId
  }
}

// --- AI Search ---
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
var searchServiceContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'

resource searchDataAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryAccount.id, searchIndexDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchDataProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryProject.id, searchIndexDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchServiceAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryAccount.id, searchServiceContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchServiceProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryProject.id, searchServiceContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// --- Cognitive Services ---
var cognitiveServicesOpenAIContributorRoleId = 'a001fd3d-188f-4b5d-821b-7da978bf7442'
resource cogServicesProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, foundryProject.id, cognitiveServicesOpenAIContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// --- Azure AI Enterprise Network Connection Approver ---
// Managed VNet에서 Outbound Rules (PE) 생성/승인에 필요
var networkConnectionApproverRoleId = 'b556d68e-0be0-4f35-a333-ad7ee1ce17ea'

resource networkApproverStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryAccount.id, networkConnectionApproverRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkConnectionApproverRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource networkApproverCosmos 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosAccountId, foundryAccount.id, networkConnectionApproverRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkConnectionApproverRoleId)
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource networkApproverSearch 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryAccount.id, networkConnectionApproverRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkConnectionApproverRoleId)
    principalId: foundryAccount.identity.principalId
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

output projectPrincipalId string = foundryProject.identity.principalId

output storageConnectionName string = storageConnection.name
output cosmosConnectionName string = cosmosConnection.name
output searchConnectionName string = searchConnection.name
