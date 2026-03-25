// =============================================================================
// dev2 환경 파라미터 - Classic Foundry Basic (Spoke VNet + Hub + Managed VNet)
// =============================================================================
// 10.3.0.0/16 대역으로 Spoke VNet 구성 (dev=10.1, ui=10.2, dev2=10.3)
//
// 사용법:
//   export HUB_VNET_ID=$(az network vnet show -g rg-aif-hub-krc-dev -n vnet-hub-dev --query id -o tsv)
//   export JUMPBOX_VNET_ID=$(az network vnet show -g rg-aif-jumpbox-krc-dev -n vnet-onprem-dev --query id -o tsv)
//   az deployment sub create --location swedencentral \
//     --template-file main.bicep --parameters parameters/dev2.bicepparam
// =============================================================================

using '../main.bicep'

// =============================================================================
// 기본 구성
// =============================================================================

param location = 'swedencentral'
param resourceGroupName = 'rg-aif-classic-basic-swc-dev2'
param environmentName = 'dev2'

// =============================================================================
// Managed VNet 구성
// =============================================================================

param managedVnetIsolationMode = 'AllowInternetOutbound'

// =============================================================================
// Hub VNet 구성 (기존 Hub VNet 재사용)
// =============================================================================

param hubVnetResourceGroup = 'rg-aif-hub-krc-dev'
param hubVnetName = 'vnet-hub-dev'
param hubVnetId = readEnvironmentVariable('HUB_VNET_ID')

// =============================================================================
// Spoke VNet 구성 — 10.3.0.0/16 대역
// dev=10.1.0.0/16, ui=10.2.0.0/16, dev2=10.3.0.0/16
// =============================================================================

param vnetAddressPrefix = '10.3.0.0/16'
param privateEndpointSubnetAddressPrefix = '10.3.1.0/24'

// =============================================================================
// Jumpbox VNet (DNS Zone 링크 + Spoke↔Jumpbox 직접 Peering)
// =============================================================================

param jumpboxVnetId = readEnvironmentVariable('JUMPBOX_VNET_ID', '')
param jumpboxVnetResourceGroup = 'rg-aif-jumpbox-krc-dev'
param jumpboxVnetName = 'vnet-onprem-dev'
