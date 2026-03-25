// =============================================================================
// 종속 리소스 모듈 - Storage Account, Key Vault
// =============================================================================
// Classic Hub의 필수 종속 리소스입니다.
// Hub의 Managed VNet이 이 리소스들에 대한 Private Endpoint를 자동 생성합니다.
// Storage: allowSharedKeyAccess=true 필요 (Hub 내부 동작)
// Key Vault: enableRbacAuthorization=true, enablePurgeProtection=true
// =============================================================================

@description('리소스 배포 위치')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Tags to apply to all resources')
param tags object = {}

// Short suffix for storage account (max 24 chars total)
var shortSuffix = take(uniqueString(resourceGroup().id, namePrefix), 8)

// =============================================================================
// Storage Account
// =============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stc${shortSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // Hub requires shared key access for internal operations
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled' // Must be Enabled initially; Hub Managed VNet will create PE automatically
    networkAcls: {
      defaultAction: 'Allow'
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

// =============================================================================
// Key Vault
// =============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${shortSuffix}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled' // Must be Enabled initially; Hub Managed VNet will create PE automatically
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// =============================================================================
// AI Search (RAG 벡터 검색용)
// =============================================================================

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: 'srch-${shortSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hostingMode: 'default'
    partitionCount: 1
    replicaCount: 1
    publicNetworkAccess: 'Disabled' // PE로만 접근 — Jumpbox에서 인덱싱/쿼리 수행
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name

output searchServiceId string = searchService.id
output searchServiceName string = searchService.name
output searchServicePrincipalId string = searchService.identity.principalId
