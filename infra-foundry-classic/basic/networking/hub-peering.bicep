// =============================================================================
// Hub VNet Peering 모듈 (cross-resource-group)
// =============================================================================
// Hub → Spoke 방향 VNet Peering을 Hub 리소스 그룹 스코프에서 생성합니다.
// Spoke → Hub Peering은 networking/main.bicep에서 생성하고,
// Hub → Spoke Peering은 이 모듈에서 hub VNet이 속한 RG 스코프로 생성합니다.
// allowGatewayTransit: true - Hub에 VPN Gateway가 있으면 Spoke에서 사용 가능
// =============================================================================

@description('Hub VNet name')
param hubVnetName string

@description('Remote VNet resource ID')
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
