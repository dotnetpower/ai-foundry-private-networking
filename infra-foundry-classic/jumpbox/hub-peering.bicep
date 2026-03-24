// =============================================================================
// Hub VNet Peering 모듈 (cross-resource-group)
// =============================================================================
// Hub VNet → On-prem(Jumpbox) VNet 방향 Peering을 생성합니다.
// Hub의 리소스 그룹 스코프에서 배포됩니다.
// allowGatewayTransit: true - Hub에 VPN Gateway가 있으면 Jumpbox에서 사용 가능
// =============================================================================

@description('Hub VNet name')
param hubVnetName string

@description('Remote VNet resource ID (on-prem jumpbox VNet)')
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
