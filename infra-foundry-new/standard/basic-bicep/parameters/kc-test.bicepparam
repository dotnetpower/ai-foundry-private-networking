// =============================================================================
// Korea Central Test Environment Parameters
// =============================================================================
// Usage: az deployment sub create --location koreacentral --template-file main.bicep --parameters parameters/kc-test.bicepparam
// =============================================================================

using '../main.bicep'

// =============================================================================
// Basic Configuration
// =============================================================================

param location = 'koreacentral'
param resourceGroupName = 'rg-aif-new-kc-test'
param environmentName = 'dev'

// =============================================================================
// Network Configuration
// =============================================================================

param vnetAddressPrefix = '10.0.0.0/16'
param agentSubnetAddressPrefix = '10.0.0.0/24'
param privateEndpointSubnetAddressPrefix = '10.0.1.0/24'
param jumpboxSubnetAddressPrefix = '10.0.2.0/24'

// =============================================================================
// Hub-Spoke Configuration (empty = standalone VNet)
// =============================================================================

param hubVnetId = ''
param hubVnetResourceGroup = ''
param hubVnetName = ''

// =============================================================================
// Jumpbox Configuration (disabled for quick test)
// =============================================================================

param deployJumpbox = false
param jumpboxAdminUsername = 'azureuser'
param jumpboxAdminPassword = ''

// =============================================================================
// Tags
// =============================================================================

param tags = {
  Environment: 'dev'
  Project: 'AI-Foundry-Private-Networking'
  ManagedBy: 'Bicep'
  TestDate: '2026-03-17'
}
