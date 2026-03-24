// =============================================================================
// Jumpbox - On-premises 시뮬레이션 (Windows VM + 자체 VNet + Hub Peering)
// =============================================================================
// 온프레미스 네트워크를 시뮬레이션하는 Windows VM을 자체 VNet에 배포합니다.
// Hub VNet과 Peering하여 Hub-Spoke 네트워크 토폴로지를 통해
// AI Foundry에 접근할 수 있습니다.
// ⚠️ Spoke VNet과도 직접 Peering 필요 (VNet Peering은 transitive하지 않음)
//
// Topology:
//   Jumpbox VNet (on-prem) ←→ Hub VNet ←→ AI Foundry Managed VNet
// =============================================================================

targetScope = 'subscription'

// =============================================================================
// Parameters
// =============================================================================

@description('Location for all resources')
param location string = 'swedencentral'

@description('Resource group name for jumpbox')
param resourceGroupName string = 'rg-aif-jumpbox-krc'

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environmentName string = 'dev'

@description('Hub VNet resource ID for peering')
param hubVnetId string

@description('Hub VNet resource group name')
param hubVnetResourceGroup string

@description('Hub VNet name')
param hubVnetName string

@description('Jumpbox VNet address prefix (simulates on-prem network)')
param jumpboxVnetAddressPrefix string = '172.16.0.0/16'

@description('Jumpbox subnet address prefix')
param jumpboxSubnetAddressPrefix string = '172.16.1.0/24'

@description('Admin username for VM')
param adminUsername string = 'azureuser'

@description('Admin password for VM')
@secure()
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_D4s_v3'

@description('Allowed source IP for RDP access')
param allowedRdpSourceIP string = '*'

@description('Tags')
param tags object = {
  Environment: environmentName
  Project: 'AI-Foundry-OnPrem-Simulation'
  ManagedBy: 'Bicep'
}

// =============================================================================
// Variables
// =============================================================================

var namePrefix = 'onprem-${environmentName}'

// =============================================================================
// Resource Group
// =============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// Jumpbox Resources (deployed inside the RG)
// =============================================================================

module jumpboxResources 'vm.bicep' = {
  scope: rg
  name: 'jumpbox-vm-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    jumpboxVnetAddressPrefix: jumpboxVnetAddressPrefix
    jumpboxSubnetAddressPrefix: jumpboxSubnetAddressPrefix
    allowedRdpSourceIP: allowedRdpSourceIP
    hubVnetId: hubVnetId
    hubVnetResourceGroup: hubVnetResourceGroup
    hubVnetName: hubVnetName
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    tags: tags
  }
}

// =============================================================================
// Outputs
// =============================================================================

output resourceGroupName string = rg.name
output vmName string = jumpboxResources.outputs.vmName
output publicIpAddress string = jumpboxResources.outputs.publicIpAddress
output privateIpAddress string = jumpboxResources.outputs.privateIpAddress
output jumpboxVnetId string = jumpboxResources.outputs.vnetId
