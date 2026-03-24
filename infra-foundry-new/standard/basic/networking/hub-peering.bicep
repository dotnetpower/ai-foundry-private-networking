// =============================================================================
// Hub VNet Peering Module (cross-resource-group)
// =============================================================================
// Hub → Spoke 방향 VNet Peering을 Hub 리소스 그룹 스코프에서 생성합니다.
// =============================================================================

@description('Hub VNet name')
param hubVnetName string

@description('Remote (Spoke) VNet resource ID')
param remoteVnetId string

@description('Peering name')
param peeringName string

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: hubVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: hubVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}
