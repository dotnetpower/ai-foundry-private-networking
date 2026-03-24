// =============================================================================
// 네트워킹 모듈 - Spoke VNet + Hub Peering + Jumpbox Peering + Private DNS Zones
// =============================================================================
// Spoke VNet을 생성하고 Hub VNet과 양방향 Peering을 구성합니다.
// Jumpbox VNet과도 직접 Peering이 필요합니다 (VNet Peering은 transitive하지 않음).
// Private DNS Zones을 생성하고 Spoke + Jumpbox VNet에 링크합니다.
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Spoke VNet address prefix')
param vnetAddressPrefix string = '10.1.0.0/16'

@description('Private Endpoint subnet address prefix')
param privateEndpointSubnetAddressPrefix string = '10.1.1.0/24'

@description('Hub VNet resource ID for peering')
param hubVnetId string

@description('Hub VNet resource group name')
param hubVnetResourceGroup string

@description('Hub VNet name')
param hubVnetName string

@description('Jumpbox VNet ID for DNS zone linking (optional)')
param jumpboxVnetId string = ''

@description('Jumpbox VNet resource group name (for cross-RG peering)')
param jumpboxVnetResourceGroup string = ''

@description('Jumpbox VNet name (for cross-RG peering)')
param jumpboxVnetName string = ''

@description('Tags')
param tags object = {}

// =============================================================================
// NSG - Private Endpoint subnet
// =============================================================================

resource nsgPe 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-${namePrefix}-pe'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// =============================================================================
// Spoke VNet
// =============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-${namePrefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-privateendpoints'
        properties: {
          addressPrefix: privateEndpointSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgPe.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// VNet Peering: Spoke → Hub
// =============================================================================

resource peeringToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnet
  name: 'peer-spoke-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
  }
}

// =============================================================================
// VNet Peering: Hub → Spoke (cross-RG)
// =============================================================================

module hubPeering 'hub-peering.bicep' = {
  scope: resourceGroup(hubVnetResourceGroup)
  name: 'hub-to-spoke-${namePrefix}-peering'
  params: {
    hubVnetName: hubVnetName
    remoteVnetId: vnet.id
    peeringName: 'peer-hub-to-${namePrefix}'
  }
}

// =============================================================================
// Private DNS Zones
// =============================================================================

var privateDnsZoneNames = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
  'privatelink.api.azureml.ms'
  'privatelink.notebooks.azure.net'
]

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for name in privateDnsZoneNames: {
  name: name
  location: 'global'
  tags: tags
}]

resource privateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (name, i) in privateDnsZoneNames: {
  parent: privateDnsZones[i]
  name: 'link-${namePrefix}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}]

// Link DNS zones to Jumpbox VNet (for on-prem DNS resolution)
resource privateDnsZoneLinksJumpbox 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (name, i) in privateDnsZoneNames: if (!empty(jumpboxVnetId)) {
  parent: privateDnsZones[i]
  name: 'link-jumpbox'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: jumpboxVnetId
    }
    registrationEnabled: false
  }
}]

// =============================================================================
// VNet Peering: Spoke ↔ Jumpbox (VNet Peering은 transitive하지 않으므로 직접 연결 필수)
// =============================================================================

resource peeringToJumpbox 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = if (!empty(jumpboxVnetId)) {
  parent: vnet
  name: 'peer-spoke-to-jumpbox'
  properties: {
    remoteVirtualNetwork: {
      id: jumpboxVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
  }
}

module jumpboxPeering 'hub-peering.bicep' = if (!empty(jumpboxVnetId) && !empty(jumpboxVnetResourceGroup)) {
  scope: resourceGroup(jumpboxVnetResourceGroup)
  name: 'jumpbox-to-spoke-peering'
  params: {
    hubVnetName: jumpboxVnetName
    remoteVnetId: vnet.id
    peeringName: 'peer-jumpbox-to-spoke'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output vnetId string = vnet.id
output vnetName string = vnet.name
output privateEndpointSubnetId string = vnet.properties.subnets[0].id
output privateDnsZoneIds object = {
  cognitiveServices: privateDnsZones[0].id
  openAi: privateDnsZones[1].id
  blob: privateDnsZones[2].id
  file: privateDnsZones[3].id
  keyVault: privateDnsZones[4].id
  azureml: privateDnsZones[5].id
  notebooks: privateDnsZones[6].id
}
