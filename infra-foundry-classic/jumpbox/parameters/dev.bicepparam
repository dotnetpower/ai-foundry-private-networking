// =============================================================================
// Jumpbox (On-premises Simulation) Parameters
// =============================================================================
// Prerequisites: Run scripts/setup-hub-spoke.sh FIRST to create Hub VNet
//
// Usage:
//   # 1. Hub VNet ID 확인
//   HUB_VNET_ID=$(az network vnet show --resource-group rg-aif-hub-krc-dev \
//     --name vnet-hub-dev --query id -o tsv)
//
//   # 2. Jumpbox 배포
//   az deployment sub create --location swedencentral \
//     --template-file main.bicep --parameters parameters/dev.bicepparam \
//     --parameters adminPassword='<비밀번호>' \
//     --parameters hubVnetId="${HUB_VNET_ID}"
// =============================================================================

using '../main.bicep'

param location = 'koreacentral'
param resourceGroupName = 'rg-aif-jumpbox-krc-dev'
param environmentName = 'dev'

// Hub VNet info (from setup-hub-spoke.sh)
param hubVnetResourceGroup = 'rg-aif-hub-krc-dev'
param hubVnetName = 'vnet-hub-dev'
param hubVnetId = readEnvironmentVariable('HUB_VNET_ID')

// On-prem simulation VNet (172.16.x.x to distinguish from Hub 10.0.x.x and Spoke 10.1.x.x)
param jumpboxVnetAddressPrefix = '172.16.0.0/16'
param jumpboxSubnetAddressPrefix = '172.16.1.0/24'

param adminUsername = 'azureuser'
param adminPassword = readEnvironmentVariable('ADMIN_PASSWORD')

// Restrict RDP to your IP (recommended)
param allowedRdpSourceIP = '*'
