// =============================================================================
// Private Endpoints Module - PE for Foundry, Storage, Cosmos DB, AI Search
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

@description('Private Endpoint Subnet ID')
param privateEndpointSubnetId string

@description('Foundry Account resource ID')
param foundryAccountId string

@description('Storage Account resource ID')
param storageAccountId string

@description('Cosmos DB Account resource ID')
param cosmosAccountId string

@description('AI Search Service resource ID')
param searchServiceId string

@description('Private DNS Zone IDs')
param privateDnsZoneIds object

// =============================================================================
// Private Endpoint for Foundry Account
// =============================================================================

resource peFoundry 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-foundry'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-foundry'
        properties: {
          privateLinkServiceId: foundryAccountId
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource peFoundryDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: peFoundry
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cognitiveservices'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.cognitiveservices
        }
      }
      {
        name: 'openai'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.openai
        }
      }
      {
        name: 'servicesai'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.servicesai
        }
      }
    ]
  }
}

// =============================================================================
// Private Endpoint for Storage Account (Blob)
// =============================================================================

resource peStorageBlob 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-storage-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-storage-blob'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource peStorageBlobDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: peStorageBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.blob
        }
      }
    ]
  }
}

// =============================================================================
// Private Endpoint for Cosmos DB
// =============================================================================

resource peCosmos 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-cosmos'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-cosmos'
        properties: {
          privateLinkServiceId: cosmosAccountId
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}

resource peCosmosDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: peCosmos
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmosdb'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.cosmosdb
        }
      }
    ]
  }
}

// =============================================================================
// Private Endpoint for AI Search
// =============================================================================

resource peSearch 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-search'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-search'
        properties: {
          privateLinkServiceId: searchServiceId
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}

resource peSearchDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: peSearch
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'search'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.search
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

output privateEndpointIds object = {
  foundry: peFoundry.id
  storageBlob: peStorageBlob.id
  cosmos: peCosmos.id
  search: peSearch.id
}
