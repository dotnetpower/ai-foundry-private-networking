// =============================================================================
// Customer VNet Networking - PE 전용 (Managed VNet용)
// =============================================================================
// Managed VNet에서는 Agent VNet을 Azure가 관리합니다.
// Customer VNet은 PE 전용이며, Jumpbox는 별도 VNet에 배치합니다.
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('VNet address prefix')
param vnetAddressPrefix string = '10.1.0.0/16'

@description('Private endpoint subnet address prefix')
param privateEndpointSubnetAddressPrefix string = '10.1.0.0/24'

@description('Deploy Application Gateway subnet')
param deployAppGatewaySubnet bool = false

@description('Application Gateway subnet address prefix')
param appGatewaySubnetAddressPrefix string = '10.1.1.0/24'

@description('Tags')
param tags object = {}

// =============================================================================
// NSG
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
// VNet (PE 서브넷만)
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
    subnets: concat([
      {
        name: 'snet-privateendpoints'
        properties: {
          addressPrefix: privateEndpointSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgPe.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ], deployAppGatewaySubnet ? [
      {
        name: 'snet-appgateway'
        properties: {
          addressPrefix: appGatewaySubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ] : [])
  }
}

// =============================================================================
// Private DNS Zones + VNet Links
// =============================================================================

var privateDnsZones = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
  'privatelink.search.windows.net'
  'privatelink.documents.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
]

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privateDnsZones: {
  name: zone
  location: 'global'
  tags: tags
}]

resource dnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZones: {
  parent: dnsZones[i]
  name: 'link-${namePrefix}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}]

// =============================================================================
// Outputs
// =============================================================================

output vnetId string = vnet.id
output vnetName string = vnet.name
output privateEndpointSubnetId string = vnet.properties.subnets[0].id
output appGatewaySubnetId string = deployAppGatewaySubnet ? vnet.properties.subnets[1].id : ''

output privateDnsZoneIds object = {
  cognitiveservices: dnsZones[0].id
  openai: dnsZones[1].id
  servicesai: dnsZones[2].id
  search: dnsZones[3].id
  cosmosdb: dnsZones[4].id
  blob: dnsZones[5].id
  file: dnsZones[6].id
}
