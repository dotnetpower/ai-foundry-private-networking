// =============================================================================
// Main Bicep Template - Azure Foundry Private Networking
// =============================================================================
// Based on: https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks
// =============================================================================

targetScope = 'subscription'

// =============================================================================
// Parameters
// =============================================================================

@description('Location for all resources')
param location string = 'swedencentral'

@description('Resource group name')
param resourceGroupName string = 'rg-aif-new'

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environmentName string = 'dev'

@description('VNet address prefix')
param vnetAddressPrefix string = '192.168.0.0/16'

@description('Agent subnet address prefix (Microsoft.App/environments delegation)')
param agentSubnetAddressPrefix string = '192.168.0.0/24'

@description('Private endpoint subnet address prefix')
param privateEndpointSubnetAddressPrefix string = '192.168.1.0/24'

@description('Jumpbox subnet address prefix')
param jumpboxSubnetAddressPrefix string = '192.168.2.0/24'

@description('Hub VNet resource ID for Hub-Spoke peering (empty = standalone VNet)')
param hubVnetId string = ''

@description('Hub VNet resource group name')
param hubVnetResourceGroup string = ''

@description('Hub VNet name')
param hubVnetName string = ''

@description('Deploy Windows Jumpbox VM')
param deployJumpbox bool = false

@description('Jumpbox admin username')
param jumpboxAdminUsername string = 'azureuser'

@description('Jumpbox admin password')
@secure()
param jumpboxAdminPassword string = ''

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  Project: 'AI-Foundry-Private-Networking'
  ManagedBy: 'Bicep'
  CreatedDate: '2026-03-17'
}

// =============================================================================
// Variables
// =============================================================================

var namePrefix = 'aifoundry-${environmentName}'

// =============================================================================
// Resource Group
// =============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// Networking Module
// =============================================================================

module networking 'networking/main.bicep' = {
  scope: rg
  name: 'networking-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    vnetAddressPrefix: vnetAddressPrefix
    agentSubnetAddressPrefix: agentSubnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
    jumpboxSubnetAddressPrefix: jumpboxSubnetAddressPrefix
    deployJumpboxSubnet: deployJumpbox
    hubVnetId: hubVnetId
    hubVnetResourceGroup: hubVnetResourceGroup
    hubVnetName: hubVnetName
    tags: tags
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
    namePrefix: namePrefix
    tags: tags
  }
  dependsOn: [
    networking
  ]
}

// =============================================================================
// Private Endpoints Module
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
// AI Foundry Module
// =============================================================================

module aiFoundry 'ai-foundry/main.bicep' = {
  scope: rg
  name: 'ai-foundry-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    agentSubnetId: networking.outputs.agentSubnetId
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
// Capability Host Module (PE + RBAC 완료 후 배포)
// =============================================================================

module capabilityHost 'ai-foundry/capability-host.bicep' = {
  scope: rg
  name: 'capability-host-deployment'
  params: {
    accountName: aiFoundry.outputs.foundryAccountName
    projectName: aiFoundry.outputs.foundryProjectName
    storageConnectionName: aiFoundry.outputs.storageConnectionName
    cosmosConnectionName: aiFoundry.outputs.cosmosConnectionName
    searchConnectionName: aiFoundry.outputs.searchConnectionName
  }
  dependsOn: [
    privateEndpoints
  ]
}

// =============================================================================
// Jumpbox Module (Optional)
// =============================================================================

module jumpbox 'jumpbox/main.bicep' = if (deployJumpbox) {
  scope: rg
  name: 'jumpbox-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    jumpboxSubnetId: networking.outputs.jumpboxSubnetId
    adminUsername: jumpboxAdminUsername
    adminPassword: jumpboxAdminPassword
    tags: tags
  }
  dependsOn: [
    privateEndpoints
  ]
}

// =============================================================================
// Outputs
// =============================================================================

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id

output vnetId string = networking.outputs.vnetId
output vnetName string = networking.outputs.vnetName
output hubSpokeEnabled bool = !empty(hubVnetId)

output foundryAccountName string = aiFoundry.outputs.foundryAccountName
output foundryAccountEndpoint string = aiFoundry.outputs.foundryAccountEndpoint
output foundryProjectName string = aiFoundry.outputs.foundryProjectName

output storageAccountName string = dependentResources.outputs.storageAccountName
output cosmosAccountName string = dependentResources.outputs.cosmosAccountName
output searchServiceName string = dependentResources.outputs.searchServiceName

output windowsJumpboxPrivateIp string = deployJumpbox ? jumpbox!.outputs.windowsVmPrivateIp : 'not-deployed'
output windowsJumpboxPublicIp string = deployJumpbox ? jumpbox!.outputs.windowsVmPublicIp : 'not-deployed'
