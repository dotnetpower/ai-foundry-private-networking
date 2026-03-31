// =============================================================================
// Private DNS Zones → Jumpbox VNet Link
// =============================================================================
// Jumpbox VNet에서 PE의 Private DNS를 해석할 수 있도록
// Customer VNet에서 생성한 DNS Zone을 Jumpbox VNet에도 링크합니다.
// =============================================================================

@description('Resource name prefix')
param namePrefix string

@description('Jumpbox VNet resource ID')
param jumpboxVnetId string

// DNS Zone names (Customer VNet에서 이미 생성됨)
var privateDnsZones = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
  'privatelink.search.windows.net'
  'privatelink.documents.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
]

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' existing = [for zone in privateDnsZones: {
  name: zone
}]

resource dnsZoneLinksJumpbox 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZones: {
  parent: dnsZones[i]
  name: 'link-${namePrefix}-jumpbox'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: jumpboxVnetId
    }
  }
}]
