// =============================================================================
// Private Endpoints 모듈 - Storage, Key Vault, OpenAI, Hub Workspace, AI Search
// =============================================================================
// Spoke VNet의 PE 서브넷에 각 리소스의 Private Endpoint를 생성합니다.
// DNS Zone Group을 통해 Private DNS Zone에 A 레코드 자동 등록
// Jumpbox에서 DNS 조회 시 PE Private IP로 해석됩니다.
// =============================================================================

@description('리소스 배포 위치')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Private Endpoint subnet ID')
param privateEndpointSubnetId string

@description('Storage Account resource ID')
param storageAccountId string

@description('Key Vault resource ID')
param keyVaultId string

@description('OpenAI Account resource ID')
param openAiAccountId string

@description('AI Hub workspace resource ID')
param hubId string

@description('AI Search resource ID')
param searchServiceId string

@description('Private DNS Zone IDs')
param privateDnsZoneIds object

@description('Tags')
param tags object = {}

// =============================================================================
// Storage Account - Blob PE
// =============================================================================

resource storageBlobPe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-${namePrefix}-blob'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource storageBlobDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: storageBlobPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.blob
        }
      }
    ]
  }
}

// =============================================================================
// Storage Account - File PE
// =============================================================================

resource storageFilePe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-file'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-${namePrefix}-file'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: ['file']
        }
      }
    ]
  }
}

resource storageFileDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: storageFilePe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'file-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.file
        }
      }
    ]
  }
}

// =============================================================================
// Key Vault PE
// =============================================================================

resource keyVaultPe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-kv'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-${namePrefix}-kv'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource keyVaultDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: keyVaultPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.keyVault
        }
      }
    ]
  }
}

// =============================================================================
// OpenAI PE
// =============================================================================

resource openAiPe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-oai'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-${namePrefix}-oai'
        properties: {
          privateLinkServiceId: openAiAccountId
          groupIds: ['account']
        }
      }
    ]
  }
}

resource openAiDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: openAiPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cognitiveservices-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.cognitiveServices
        }
      }
      {
        name: 'openai-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.openAi
        }
      }
    ]
  }
}

// =============================================================================
// AI Hub Workspace PE (for ai.azure.com Portal access)
// =============================================================================

resource hubPe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-hub'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-${namePrefix}-hub'
        properties: {
          privateLinkServiceId: hubId
          groupIds: ['amlworkspace']
        }
      }
    ]
  }
}

resource hubDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: hubPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'azureml-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.azureml
        }
      }
      {
        name: 'notebooks-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.notebooks
        }
      }
    ]
  }
}

// =============================================================================
// AI Search PE
// =============================================================================

resource searchPe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${namePrefix}-search'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-${namePrefix}-search'
        properties: {
          privateLinkServiceId: searchServiceId
          groupIds: ['searchService']
        }
      }
    ]
  }
}

resource searchDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: searchPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'search-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneIds.search
        }
      }
    ]
  }
}
