// =============================================================================
// Dependent Resources Module - Storage, Cosmos DB, AI Search
// =============================================================================
// Managed VNet 방식에서는 Azure가 PE를 자동 관리하므로
// publicNetworkAccess: Disabled로 설정합니다.
// =============================================================================

@description('Location for all resources')
param location string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Tags to apply to all resources')
param tags object = {}

var shortSuffix = take(uniqueSuffix, 8)

// =============================================================================
// Storage Account
// =============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${shortSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource agentsDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'agents-data'
  properties: {
    publicAccess: 'None'
  }
}

// =============================================================================
// Azure Cosmos DB
// =============================================================================

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: 'cosmos-${shortSuffix}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Disabled'
    networkAclBypass: 'AzureServices'
    disableLocalAuth: true
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-02-15-preview' = {
  parent: cosmosAccount
  name: 'agentdb'
  properties: {
    resource: {
      id: 'agentdb'
    }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-02-15-preview' = {
  parent: cosmosDatabase
  name: 'threads'
  properties: {
    resource: {
      id: 'threads'
      partitionKey: {
        paths: [
          '/threadId'
        ]
        kind: 'Hash'
      }
    }
  }
}

// =============================================================================
// Azure AI Search
// =============================================================================

resource searchService 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: 'srch-${shortSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'standard'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'disabled'
    networkRuleSet: {
      bypass: 'AzureServices'
    }
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    semanticSearch: 'standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name

output cosmosAccountId string = cosmosAccount.id
output cosmosAccountName string = cosmosAccount.name

output searchServiceId string = searchService.id
output searchServiceName string = searchService.name
