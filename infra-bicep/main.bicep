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
param resourceGroupName string = 'rg-aifoundry-bicep'

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

@description('Bastion subnet address prefix')
param bastionSubnetAddressPrefix string = '192.168.255.0/26'

@description('Deploy Jumpbox VMs and Azure Bastion')
param deployJumpbox bool = false

@description('Deploy Linux Jumpbox')
param deployLinuxJumpbox bool = false

@description('Deploy Windows Jumpbox')
param deployWindowsJumpbox bool = true

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

module networking 'modules/networking/main.bicep' = {
  scope: rg
  name: 'networking-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    vnetAddressPrefix: vnetAddressPrefix
    agentSubnetAddressPrefix: agentSubnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
    jumpboxSubnetAddressPrefix: jumpboxSubnetAddressPrefix
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
    deployJumpboxSubnets: deployJumpbox
    tags: tags
  }
}

// =============================================================================
// Dependent Resources Module (Storage, Cosmos DB, AI Search)
// =============================================================================

module dependentResources 'modules/dependent-resources/main.bicep' = {
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

module privateEndpoints 'modules/private-endpoints/main.bicep' = {
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

module aiFoundry 'modules/ai-foundry/main.bicep' = {
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
// Jumpbox Module (Optional)
// =============================================================================

module jumpbox 'modules/jumpbox/main.bicep' = if (deployJumpbox) {
  scope: rg
  name: 'jumpbox-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    jumpboxSubnetId: networking.outputs.jumpboxSubnetId
    bastionSubnetId: networking.outputs.bastionSubnetId
    adminUsername: jumpboxAdminUsername
    adminPassword: jumpboxAdminPassword
    deployLinuxJumpbox: deployLinuxJumpbox
    deployWindowsJumpbox: deployWindowsJumpbox
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

output foundryAccountName string = aiFoundry.outputs.foundryAccountName
output foundryAccountEndpoint string = aiFoundry.outputs.foundryAccountEndpoint
output foundryProjectName string = aiFoundry.outputs.foundryProjectName

output storageAccountName string = dependentResources.outputs.storageAccountName
output cosmosAccountName string = dependentResources.outputs.cosmosAccountName
output searchServiceName string = dependentResources.outputs.searchServiceName

output bastionName string = deployJumpbox ? jumpbox.outputs.bastionName : 'not-deployed'
output linuxJumpboxPrivateIp string = (deployJumpbox && deployLinuxJumpbox) ? jumpbox.outputs.linuxVmPrivateIp : 'not-deployed'
output windowsJumpboxPrivateIp string = (deployJumpbox && deployWindowsJumpbox) ? jumpbox.outputs.windowsVmPrivateIp : 'not-deployed'
