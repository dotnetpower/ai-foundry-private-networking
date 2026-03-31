// =============================================================================
// Jumpbox VNet - 별도 VNet + Customer VNet 피어링
// =============================================================================
// Customer VNet(PE 전용)과 분리된 Jumpbox 전용 VNet.
// 피어링을 통해 Customer VNet의 PE/Private DNS를 사용합니다.
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Jumpbox VNet address prefix')
param vnetAddressPrefix string = '10.2.0.0/16'

@description('Jumpbox subnet address prefix')
param jumpboxSubnetAddressPrefix string = '10.2.0.0/24'

@description('Customer VNet resource ID (피어링 대상)')
param customerVnetId string

@description('Customer VNet name (피어링 대상)')
param customerVnetName string

@description('Tags')
param tags object = {}

// =============================================================================
// NSG
// =============================================================================

resource nsgJumpbox 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
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
// Jumpbox VNet
// =============================================================================

resource jumpboxVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-${namePrefix}-jumpbox'
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
        name: 'snet-jumpbox'
        properties: {
          addressPrefix: jumpboxSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgJumpbox.id
          }
          defaultOutboundAccess: false
        }
      }
    ]
  }
}

// =============================================================================
// VNet Peering: Jumpbox VNet ↔ Customer VNet (양방향)
// =============================================================================

resource peeringToCustomer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: jumpboxVnet
  name: 'peer-jumpbox-to-customer'
  properties: {
    remoteVirtualNetwork: {
      id: customerVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
  }
}

resource customerVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: customerVnetName
}

resource peeringToJumpbox 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: customerVnet
  name: 'peer-customer-to-jumpbox'
  properties: {
    remoteVirtualNetwork: {
      id: jumpboxVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
  }
}

// =============================================================================
// Outputs
// =============================================================================

output jumpboxVnetId string = jumpboxVnet.id
output jumpboxVnetName string = jumpboxVnet.name
output jumpboxSubnetId string = jumpboxVnet.properties.subnets[0].id
