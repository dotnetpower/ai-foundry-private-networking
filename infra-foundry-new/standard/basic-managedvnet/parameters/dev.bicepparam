// =============================================================================
// Development Environment Parameters - Managed VNet (Preview)
// =============================================================================

using '../main.bicep'

param location = 'swedencentral'
param resourceGroupName = 'rg-aif-mvnet-swc-dev'
param environmentName = 'dev'

// Customer VNet (PE 전용): 10.1.0.0/16
param customerVnetAddressPrefix = '10.1.0.0/16'
param privateEndpointSubnetAddressPrefix = '10.1.0.0/24'

// Jumpbox VNet (별도): 10.2.0.0/16
param jumpboxVnetAddressPrefix = '10.2.0.0/16'
param jumpboxSubnetAddressPrefix = '10.2.0.0/24'

// Jumpbox (기본 비활성)
param deployJumpbox = false
param jumpboxAdminUsername = 'azureuser'
param jumpboxAdminPassword = ''

param tags = {
  Environment: 'dev'
  Project: 'AI-Foundry-ManagedVNet'
  ManagedBy: 'Bicep'
}
