// =============================================================================
// Main Bicep Template - Azure Foundry Managed VNet (Preview)
// =============================================================================
// 아키텍처:
//   Managed VNet (Azure 관리)    — Agent용 PE (자동)
//   Customer VNet (10.1.0.0/16)  — 의존 리소스 PE 전용
//   Jumpbox VNet (10.2.0.0/16)   — Jumpbox VM (Public IP)
//   Customer VNet ↔ Jumpbox VNet 피어링
//
// ⚠️ Preview 기능 — 프로덕션 비권장
// =============================================================================

targetScope = 'subscription'

// =============================================================================
// Parameters
// =============================================================================

@description('Location for all resources')
param location string = 'swedencentral'

@description('Resource group name')
param resourceGroupName string = 'rg-aif-mvnet'

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environmentName string = 'dev'

@description('Customer VNet address prefix (PE 전용)')
param customerVnetAddressPrefix string = '10.1.0.0/16'

@description('Private endpoint subnet address prefix')
param privateEndpointSubnetAddressPrefix string = '10.1.0.0/24'

@description('Deploy Windows Jumpbox VM')
param deployJumpbox bool = false

@description('Jumpbox VNet address prefix (별도 VNet)')
param jumpboxVnetAddressPrefix string = '10.2.0.0/16'

@description('Jumpbox subnet address prefix')
param jumpboxSubnetAddressPrefix string = '10.2.0.0/24'

@description('Jumpbox admin username')
param jumpboxAdminUsername string = 'azureuser'

@description('Jumpbox admin password')
@secure()
param jumpboxAdminPassword string = ''

@description('RDP 접속을 허용할 소스 IP (CIDR). 예: 61.80.8.142/32')
param allowedRdpSourceIp string = '*'

@description('Deploy Application Gateway (온프레미스 리소스 접근용)')
param deployAppGateway bool = false

@description('Application Gateway subnet address prefix')
param appGatewaySubnetAddressPrefix string = '10.1.1.0/24'

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  Project: 'AI-Foundry-ManagedVNet'
  ManagedBy: 'Bicep'
}

// =============================================================================
// Variables
// =============================================================================

var namePrefix = 'aifmvnet-${environmentName}'

// =============================================================================
// Resource Group
// =============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// Customer VNet (PE 전용, Private DNS Zones)
// =============================================================================

module networking 'networking/main.bicep' = {
  scope: rg
  name: 'networking-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    vnetAddressPrefix: customerVnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
    deployAppGatewaySubnet: deployAppGateway
    appGatewaySubnetAddressPrefix: appGatewaySubnetAddressPrefix
    tags: tags
  }
}

// =============================================================================
// Application Gateway (선택 — 온프레미스 리소스 접근용)
// =============================================================================

module appGateway 'application-gateway/main.bicep' = if (deployAppGateway) {
  scope: rg
  name: 'appgateway-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    appGatewaySubnetId: networking.outputs.appGatewaySubnetId
    tags: tags
  }
  dependsOn: [
    networking
  ]
}

// =============================================================================
// Jumpbox VNet (별도 VNet, Customer VNet과 피어링)
// =============================================================================

module jumpboxNetworking 'jumpbox/networking.bicep' = if (deployJumpbox) {
  scope: rg
  name: 'jumpbox-networking-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    vnetAddressPrefix: jumpboxVnetAddressPrefix
    jumpboxSubnetAddressPrefix: jumpboxSubnetAddressPrefix
    customerVnetId: networking.outputs.vnetId
    customerVnetName: networking.outputs.vnetName
    allowedRdpSourceIp: allowedRdpSourceIp
    tags: tags
  }
}

// =============================================================================
// DNS Zone → Jumpbox VNet Link (Jumpbox에서 PE Private DNS 해석)
// =============================================================================

module dnsJumpboxLinks 'networking/dns-jumpbox-link.bicep' = if (deployJumpbox) {
  scope: rg
  name: 'dns-jumpbox-links-deployment'
  params: {
    namePrefix: namePrefix
    jumpboxVnetId: jumpboxNetworking!.outputs.jumpboxVnetId
  }
}

// =============================================================================
// Dependent Resources Module (Storage, Cosmos DB, AI Search)
// =============================================================================

module dependentResources 'dependent-resources/main.bicep' = {
  scope: rg
  name: 'dependent-resources-deployment'
  params: {
    location: location
    tags: tags
  }
  dependsOn: [
    networking
  ]
}

// =============================================================================
// Customer VNet Private Endpoints (Jumpbox에서 데이터 플레인 접근용)
// =============================================================================

module privateEndpoints 'private-endpoints/main.bicep' = {
  scope: rg
  name: 'private-endpoints-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    foundryAccountId: aiFoundry.outputs.foundryAccountId
    storageAccountId: dependentResources.outputs.storageAccountId
    cosmosAccountId: dependentResources.outputs.cosmosAccountId
    searchServiceId: dependentResources.outputs.searchServiceId
    privateDnsZoneIds: networking.outputs.privateDnsZoneIds
    tags: tags
  }
}

// =============================================================================
// AI Foundry Module (Managed VNet — useMicrosoftManagedNetwork: true)
// =============================================================================

module aiFoundry 'ai-foundry/main.bicep' = {
  scope: rg
  name: 'ai-foundry-deployment'
  params: {
    location: location
    storageAccountId: dependentResources.outputs.storageAccountId
    storageAccountName: dependentResources.outputs.storageAccountName
    cosmosAccountId: dependentResources.outputs.cosmosAccountId
    cosmosAccountName: dependentResources.outputs.cosmosAccountName
    searchServiceId: dependentResources.outputs.searchServiceId
    searchServiceName: dependentResources.outputs.searchServiceName
    tags: tags
  }
}

// =============================================================================
// Managed Network + Outbound Rules (Azure 관리 PE)
// =============================================================================

module managedNetwork 'ai-foundry/managed-network.bicep' = {
  scope: rg
  name: 'managed-network-deployment'
  params: {
    accountName: aiFoundry.outputs.foundryAccountName
    storageAccountId: dependentResources.outputs.storageAccountId
    cosmosAccountId: dependentResources.outputs.cosmosAccountId
    searchServiceId: dependentResources.outputs.searchServiceId
  }
}

// =============================================================================
// Account Capability Host (Project Capability Host 전에 필수)
// =============================================================================

#disable-next-line BCP081
module accountCapabilityHost 'ai-foundry/account-capability-host.bicep' = {
  scope: rg
  name: 'account-capability-host-deployment'
  params: {
    accountName: aiFoundry.outputs.foundryAccountName
  }
  dependsOn: [
    managedNetwork
    privateEndpoints
  ]
}

// =============================================================================
// Project Capability Host (Account Capability Host 후에 생성)
// =============================================================================

module capabilityHost 'ai-foundry/capability-host.bicep' = {
  scope: rg
  name: 'capability-host-deployment'
  params: {
    accountName: aiFoundry.outputs.foundryAccountName
    projectName: aiFoundry.outputs.foundryProjectName
    cosmosDBConnection: aiFoundry.outputs.cosmosConnectionName
    azureStorageConnection: aiFoundry.outputs.storageConnectionName
    aiSearchConnection: aiFoundry.outputs.searchConnectionName
  }
  dependsOn: [
    accountCapabilityHost
  ]
}

// =============================================================================
// Jumpbox VM (Optional — Public IP + RDP)
// =============================================================================

module jumpbox 'jumpbox/main.bicep' = if (deployJumpbox) {
  scope: rg
  name: 'jumpbox-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    jumpboxSubnetId: jumpboxNetworking!.outputs.jumpboxSubnetId
    adminUsername: jumpboxAdminUsername
    adminPassword: jumpboxAdminPassword
    tags: tags
  }
  dependsOn: [
    privateEndpoints
    dnsJumpboxLinks
  ]
}

// =============================================================================
// Outputs
// =============================================================================

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id

output customerVnetId string = networking.outputs.vnetId
output customerVnetName string = networking.outputs.vnetName

output foundryAccountName string = aiFoundry.outputs.foundryAccountName
output foundryAccountEndpoint string = aiFoundry.outputs.foundryAccountEndpoint
output foundryProjectName string = aiFoundry.outputs.foundryProjectName

output storageAccountName string = dependentResources.outputs.storageAccountName
output cosmosAccountName string = dependentResources.outputs.cosmosAccountName
output searchServiceName string = dependentResources.outputs.searchServiceName

output jumpboxVnetId string = deployJumpbox ? jumpboxNetworking!.outputs.jumpboxVnetId : 'not-deployed'
output windowsJumpboxPublicIp string = deployJumpbox ? jumpbox!.outputs.windowsVmPublicIp : 'not-deployed'
output appGatewayId string = deployAppGateway ? appGateway!.outputs.appGatewayId : 'not-deployed'
output appGatewayName string = deployAppGateway ? appGateway!.outputs.appGatewayName : 'not-deployed'
