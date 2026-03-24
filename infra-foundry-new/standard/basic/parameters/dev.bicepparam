// =============================================================================
// Development Environment Parameters
// =============================================================================
// Usage: az deployment sub create --location swedencentral --template-file main.bicep --parameters parameters/dev.bicepparam
// =============================================================================

using '../main.bicep'

// =============================================================================
// Basic Configuration
// =============================================================================

param location = 'swedencentral'
param resourceGroupName = 'rg-aif-new-swc-dev'
param environmentName = 'dev'

// =============================================================================
// Network Configuration
// =============================================================================

// VNet: 192.168.0.0/16 (65,536 addresses)
param vnetAddressPrefix = '192.168.0.0/16'

// Agent Subnet: 192.168.0.0/24 (256 addresses)
// - Microsoft.App/environments delegation required
// - Hosts Foundry Agent runtime
param agentSubnetAddressPrefix = '192.168.0.0/24'

// Private Endpoint Subnet: 192.168.1.0/24 (256 addresses)
// - Hosts Private Endpoints for Foundry, Storage, Cosmos DB, AI Search
param privateEndpointSubnetAddressPrefix = '192.168.1.0/24'

// Jumpbox Subnet: 192.168.2.0/24 (256 addresses)
// - Hosts Windows Jumpbox VM
param jumpboxSubnetAddressPrefix = '192.168.2.0/24'

// =============================================================================
// Hub-Spoke Configuration
// =============================================================================

// Hub VNet ID - setup-hub-spoke.sh로 생성한 Hub VNet의 리소스 ID
// 비어 있으면 standalone VNet으로 배포됩니다.
// 예: /subscriptions/{sub}/resourceGroups/rg-aif-hub-swc-dev/providers/Microsoft.Network/virtualNetworks/vnet-hub-dev
param hubVnetId = ''
param hubVnetResourceGroup = ''
param hubVnetName = ''

// =============================================================================
// Jumpbox Configuration
// =============================================================================

// Set to true to deploy Windows Jumpbox VM
param deployJumpbox = true

// Jumpbox credentials
param jumpboxAdminUsername = 'azureuser'

// IMPORTANT: Replace with a secure password or use Key Vault reference
// Minimum requirements: 12+ chars, uppercase, lowercase, number, special char
param jumpboxAdminPassword = 'ChangeMe123!@#'

// =============================================================================
// Tags
// =============================================================================

param tags = {
  Environment: 'dev'
  Project: 'AI-Foundry-Private-Networking'
  ManagedBy: 'Bicep'
  CostCenter: 'AI-Research'
  Owner: 'Platform-Team'
}
