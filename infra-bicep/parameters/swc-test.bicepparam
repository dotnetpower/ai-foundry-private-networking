// =============================================================================
// Sweden Central Test Environment Parameters
// =============================================================================

using '../main.bicep'

param location = 'swedencentral'
param resourceGroupName = 'rg-aif-swc5'
param environmentName = 'dev'

// Network Configuration
param vnetAddressPrefix = '192.168.0.0/16'
param agentSubnetAddressPrefix = '192.168.0.0/24'
param privateEndpointSubnetAddressPrefix = '192.168.1.0/24'
param jumpboxSubnetAddressPrefix = '192.168.2.0/24'
param bastionSubnetAddressPrefix = '192.168.255.0/26'

// Jumpbox disabled for quick test
param deployJumpbox = false
param deployLinuxJumpbox = false
param deployWindowsJumpbox = false
param jumpboxAdminUsername = 'azureuser'
param jumpboxAdminPassword = ''

param tags = {
  Environment: 'dev'
  Project: 'AI-Foundry-Private-Networking'
  ManagedBy: 'Bicep'
}
