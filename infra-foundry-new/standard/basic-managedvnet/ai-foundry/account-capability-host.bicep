// =============================================================================
// Account Capability Host - Managed VNet 전용
// =============================================================================
// Project Capability Host 생성 전에 Account-level Capability Host가 필요합니다.
// =============================================================================

@description('Foundry Account name')
param accountName string

@description('Capability Host name')
param capabilityHostName string = 'caphost-account'

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

#disable-next-line BCP081
resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = {
  name: capabilityHostName
  parent: account
  properties: {
    #disable-next-line BCP037
    capabilityHostKind: 'Agents'
  }
}

output capabilityHostName string = accountCapabilityHost.name
