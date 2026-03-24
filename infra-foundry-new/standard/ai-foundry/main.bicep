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
  name: 'text-embedding-ada-002'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
  }
  dependsOn: [
    gpt4oDeployment
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

// =============================================================================
// =============================================================================
// Capability Host (Standard Agent Setup)
// NOTE: Capability Host requires manual setup via Azure Portal or CLI after deployment
// The virtualNetworkSubnetResourceId property is not yet available in this API version
// =============================================================================

// resource capabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
//   parent: foundryProject
//   name: 'capability-host'
//   properties: {
//     capabilityHostKind: 'Agents'
//     vectorStoreConnections: [
//       searchConnection.name
//     ]
//     storageConnections: [
//       storageConnection.name
//     ]
//     threadStorageConnections: [
//       cosmosConnection.name
//     ]
//     aiServicesConnections: []
//   }
// }

// =============================================================================
// RBAC Role Assignments (MS Official Sample Requirements)
// =============================================================================

// Storage Blob Data Owner for Foundry Account System Identity
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

// Storage Blob Data Owner for Project System Identity
resource storageProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, foundryProject.id, storageBlobDataOwnerRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Cosmos DB Operator for Foundry Account System Identity
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

// Cosmos DB Operator for Project System Identity
resource cosmosProjectOperatorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosAccountId, foundryProject.id, cosmosDbOperatorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cosmosDbOperatorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Index Data Contributor for Foundry Account System Identity
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

// Search Index Data Contributor for Project System Identity
resource searchProjectDataRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryProject.id, searchIndexDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Service Contributor for Foundry Account System Identity
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

// Search Service Contributor for Project System Identity
resource searchProjectServiceRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, foundryProject.id, searchServiceContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
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
