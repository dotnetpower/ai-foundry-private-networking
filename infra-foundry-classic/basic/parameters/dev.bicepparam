// =============================================================================
// 개발 환경 파라미터 - Classic Foundry Basic (Spoke VNet + Hub + Managed VNet)
// =============================================================================
// 사전 조건: scripts/setup-hub-spoke.sh 를 먼저 실행하여 Hub VNet을 생성해야 합니다.
//
// 사용법:
//   export HUB_VNET_ID=$(az network vnet show -g rg-aif-hub-krc-dev -n vnet-hub-dev --query id -o tsv)
//   export JUMPBOX_VNET_ID=$(az network vnet show -g rg-aif-jumpbox-krc-dev -n vnet-onprem-dev --query id -o tsv)
//   az deployment sub create --location swedencentral \
//     --template-file main.bicep --parameters parameters/dev.bicepparam
// =============================================================================

using '../main.bicep'

// =============================================================================
// 기본 구성
// =============================================================================

// Sweden Central: OpenAI GlobalStandard SKU 지원 리전
param location = 'swedencentral'

// 리소스 그룹 이름 - 명명 규칙: rg-aif-{type}-{region}-{env}
param resourceGroupName = 'rg-aif-classic-basic-swc-dev'

// 환경 이름 - 리소스 이름 프리픽스에 사용 (예: aifoundry-classic-dev)
param environmentName = 'dev'

// =============================================================================
// Managed VNet 구성
// Hub가 자동으로 관리하는 내부 네트워크의 격리 모드
// AllowInternetOutbound: 인터넷 아웃바운드 허용 (일반적)
// AllowOnlyApprovedOutbound: 승인된 아웃바운드만 허용 (엄격한 보안)
// =============================================================================

param managedVnetIsolationMode = 'AllowInternetOutbound'

// =============================================================================
// Hub VNet 구성 (setup-hub-spoke.sh 로 사전 생성)
// Hub VNet은 Spoke VNet과 Peering하여 네트워크 토폴로지의 중심 역할
// HUB_VNET_ID는 환경 변수에서 읽음 (배포 전 export 필수)
// =============================================================================

param hubVnetResourceGroup = 'rg-aif-hub-krc-dev'
param hubVnetName = 'vnet-hub-dev'
param hubVnetId = readEnvironmentVariable('HUB_VNET_ID')

// =============================================================================
// Spoke VNet 구성
// Hub VNet 및 다른 Spoke VNet과 주소 공간이 겹치지 않아야 합니다.
// 예: dev=10.1.0.0/16, ui=10.2.0.0/16, prod=10.3.0.0/16
// =============================================================================

param vnetAddressPrefix = '10.1.0.0/16'
param privateEndpointSubnetAddressPrefix = '10.1.1.0/24'

// =============================================================================
// Jumpbox VNet (DNS Zone 링크 + Spoke↔Jumpbox 직접 Peering)
// ⚠️ VNet Peering은 transitive하지 않습니다.
//    Jumpbox→Hub→Spoke 경로로는 Spoke PE에 접근 불가
//    → Jumpbox↔Spoke 직접 Peering이 자동 구성됩니다.
// JUMPBOX_VNET_ID: 환경 변수 (없으면 빈 문자열 → Peering 생략)
// =============================================================================

param jumpboxVnetId = readEnvironmentVariable('JUMPBOX_VNET_ID', '')
param jumpboxVnetResourceGroup = 'rg-aif-jumpbox-krc-dev'
param jumpboxVnetName = 'vnet-onprem-dev'
