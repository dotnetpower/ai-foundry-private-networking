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
param resourceGroupName = 'rg-aifoundry-bicep-dev'
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
// - Hosts Linux/Windows Jumpbox VMs
param jumpboxSubnetAddressPrefix = '192.168.2.0/24'

// Bastion Subnet: 192.168.255.0/26 (64 addresses)
// - Must be named 'AzureBastionSubnet'
// - Minimum /26 required
param bastionSubnetAddressPrefix = '192.168.255.0/26'

// =============================================================================
// Jumpbox Configuration
// =============================================================================

// Set to true to deploy Jumpbox VMs and Azure Bastion
param deployJumpbox = true

// Deploy Linux Jumpbox (Ubuntu 22.04 with Python dev environment)
param deployLinuxJumpbox = true

// Deploy Windows Jumpbox (Windows 11 Pro for Portal access)
param deployWindowsJumpbox = false

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
