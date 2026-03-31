// =============================================================================
// Networking Module - VNet, Subnets, NSG, Private DNS Zones
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Agent subnet address prefix (requires Microsoft.App/environments delegation)')
param agentSubnetAddressPrefix string = '10.0.0.0/24'

@description('Private endpoint subnet address prefix')
param privateEndpointSubnetAddressPrefix string = '10.0.1.0/24'

@description('Jumpbox subnet address prefix')
param jumpboxSubnetAddressPrefix string = '10.0.2.0/24'

@description('Deploy jumpbox subnet')
param deployJumpboxSubnet bool = false

@description('Hub VNet resource ID for Hub-Spoke peering (empty = standalone VNet)')
param hubVnetId string = ''

@description('Hub VNet resource group name')
param hubVnetResourceGroup string = ''

@description('Hub VNet name')
param hubVnetName string = ''

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Network Security Groups
// =============================================================================

resource nsgAgent 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-${namePrefix}-agent'
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

resource nsgPrivateEndpoint 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
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

resource nsgJumpbox 'Microsoft.Network/networkSecurityGroups@2023-11-01' = if (deployJumpboxSubnet) {
  name: 'nsg-${namePrefix}-jumpbox'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4095
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowInternetOutbound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

// =============================================================================
// Virtual Network
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
        name: 'snet-agent'
        properties: {
          addressPrefix: agentSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgAgent.id
          }
          delegations: [
            {
              name: 'delegation-app-environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-privateendpoints'
        properties: {
          addressPrefix: privateEndpointSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgPrivateEndpoint.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ], deployJumpboxSubnet ? [
      {
        name: 'snet-jumpbox'
        properties: {
          addressPrefix: jumpboxSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgJumpbox.id
          }
          defaultOutboundAccess: false
        }
      }
    ] : [])
  }
}

// =============================================================================
// Private DNS Zones
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

// Link DNS zones to Hub VNet (for Hub-Spoke DNS resolution)
resource dnsZoneLinksHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZones: if (!empty(hubVnetId)) {
  parent: dnsZones[i]
  name: 'link-hub'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}]

// =============================================================================
// VNet Peering: Spoke → Hub
// =============================================================================

resource peeringToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = if (!empty(hubVnetId)) {
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

module hubPeering 'hub-peering.bicep' = if (!empty(hubVnetId)) {
  scope: resourceGroup(hubVnetResourceGroup)
  name: 'hub-to-spoke-peering'
  params: {
    hubVnetName: hubVnetName
    remoteVnetId: vnet.id
    peeringName: 'peer-hub-to-${namePrefix}'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output vnetId string = vnet.id
output vnetName string = vnet.name

output agentSubnetId string = vnet.properties.subnets[0].id
output privateEndpointSubnetId string = vnet.properties.subnets[1].id
output jumpboxSubnetId string = deployJumpboxSubnet ? vnet.properties.subnets[2].id : ''

output privateDnsZoneIds object = {
  cognitiveservices: dnsZones[0].id
  openai: dnsZones[1].id
  servicesai: dnsZones[2].id
  search: dnsZones[3].id
  cosmosdb: dnsZones[4].id
  blob: dnsZones[5].id
  file: dnsZones[6].id
}
