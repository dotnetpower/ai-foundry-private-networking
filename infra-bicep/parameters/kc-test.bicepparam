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
param resourceGroupName = 'rg-aif-kc'
param environmentName = 'dev'

// =============================================================================
// Network Configuration
// =============================================================================

param vnetAddressPrefix = '192.168.0.0/16'
param agentSubnetAddressPrefix = '192.168.0.0/24'
param privateEndpointSubnetAddressPrefix = '192.168.1.0/24'
param jumpboxSubnetAddressPrefix = '192.168.2.0/24'
param bastionSubnetAddressPrefix = '192.168.255.0/26'

// =============================================================================
// Jumpbox Configuration (disabled for quick test)
// =============================================================================

param deployJumpbox = false
param deployLinuxJumpbox = false
param deployWindowsJumpbox = false
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
