// =============================================================================
// Managed Network Module - Managed VNet + Outbound Rules
// =============================================================================
// Azure가 VNet/PE를 자동 관리하는 Managed Network를 생성합니다.
// Storage, Cosmos DB, AI Search에 대한 Outbound Rules (PE)을 설정합니다.
// API: 2025-10-01-preview
// =============================================================================

@description('Foundry Account name')
param accountName string

@description('Isolation mode')
@allowed([
  'AllowInternetOutbound'
  'AllowOnlyApprovedOutbound'
])
param isolationMode string = 'AllowInternetOutbound'

@description('Storage Account resource ID')
param storageAccountId string

@description('Cosmos DB Account resource ID')
param cosmosAccountId string

@description('AI Search Service resource ID')
param searchServiceId string

// =============================================================================
// References
// =============================================================================

resource aiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

// =============================================================================
// Managed Network
// =============================================================================

#disable-next-line BCP081
resource managedNetwork 'Microsoft.CognitiveServices/accounts/managedNetworks@2025-10-01-preview' = {
  parent: aiAccount
  name: 'default'
  properties: {
    #disable-next-line BCP037
    managedNetwork: {
      IsolationMode: isolationMode
      managedNetworkKind: 'V2'
    }
  }
}

// =============================================================================
// Outbound Rules (Managed PE to dependent resources)
// =============================================================================

#disable-next-line BCP081
resource storageOutboundRule 'Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview' = {
  parent: managedNetwork
  name: 'storage-rule'
  properties: {
    #disable-next-line BCP037
    type: 'PrivateEndpoint'
    #disable-next-line BCP037
    destination: {
      serviceResourceId: storageAccountId
      subresourceTarget: 'blob'
      sparkEnabled: false
      sparkStatus: 'Inactive'
    }
    #disable-next-line BCP037
    category: 'UserDefined'
  }
}

#disable-next-line BCP081
resource cosmosOutboundRule 'Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview' = {
  parent: managedNetwork
  name: 'cosmos-rule'
  properties: {
    #disable-next-line BCP037
    type: 'PrivateEndpoint'
    #disable-next-line BCP037
    destination: {
      serviceResourceId: cosmosAccountId
      subresourceTarget: 'Sql'
      sparkEnabled: false
      sparkStatus: 'Inactive'
    }
    #disable-next-line BCP037
    category: 'UserDefined'
  }
  dependsOn: [
    storageOutboundRule
  ]
}

#disable-next-line BCP081
resource searchOutboundRule 'Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2025-10-01-preview' = {
  parent: managedNetwork
  name: 'search-rule'
  properties: {
    #disable-next-line BCP037
    type: 'PrivateEndpoint'
    #disable-next-line BCP037
    destination: {
      serviceResourceId: searchServiceId
      subresourceTarget: 'searchService'
      sparkEnabled: false
      sparkStatus: 'Inactive'
    }
    #disable-next-line BCP037
    category: 'UserDefined'
  }
  dependsOn: [
    cosmosOutboundRule
  ]
}

// =============================================================================
// Outputs
// =============================================================================

output managedNetworkName string = managedNetwork.name
