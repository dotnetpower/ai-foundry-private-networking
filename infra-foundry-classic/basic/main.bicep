// =============================================================================
// 메인 Bicep 템플릿 - AI Foundry Classic Basic (Hub-Spoke VNet + Managed VNet)
// =============================================================================
// Classic AI Foundry Hub를 Spoke VNet + Hub VNet Peering 구성으로 배포합니다.
// Spoke VNet에 Private Endpoint를 호스팅하여 종속 리소스에 프라이빗 접근합니다.
// Hub의 Managed VNet은 내부 컴퓨팅 네트워킹을 자동으로 관리합니다.
// Jumpbox는 별도 배포: infra-foundry-classic/jumpbox/
//
// 배포 순서: Networking → Dependent Resources → AI Foundry → Private Endpoints
// =============================================================================

// 구독 수준 배포 (리소스 그룹을 직접 생성)
targetScope = 'subscription'

// =============================================================================
// 파라미터 - 배포 시 parameters/*.bicepparam 파일로 값 전달
// =============================================================================

@description('모든 리소스의 배포 위치 (Sweden Central: OpenAI GlobalStandard 지원)')
param location string = 'swedencentral'

@description('리소스 그룹 이름')
param resourceGroupName string = 'rg-aif-classic-basic-swc'

@description('환경 이름 - 리소스 이름 프리픽스에 사용')
param environmentName string = 'dev'

@description('Managed VNet 격리 모드: AllowInternetOutbound(인터넷 아웃바운드 허용) 또는 AllowOnlyApprovedOutbound(승인된 아웃바운드만 허용)')
@allowed([
  'AllowInternetOutbound'
  'AllowOnlyApprovedOutbound'
])
param managedVnetIsolationMode string = 'AllowInternetOutbound'

@description('Hub VNet 리소스 ID - setup-hub-spoke.sh로 사전 생성한 Hub VNet')
param hubVnetId string

@description('Hub VNet 리소스 그룹 이름 (cross-RG peering에 필요)')
param hubVnetResourceGroup string

@description('Hub VNet 이름 (cross-RG peering에 필요)')
param hubVnetName string

@description('Spoke VNet 주소 대역 (Hub VNet 및 다른 Spoke와 겹치지 않아야 함)')
param vnetAddressPrefix string = '10.1.0.0/16'

@description('Private Endpoint 서브넷 주소 대역')
param privateEndpointSubnetAddressPrefix string = '10.1.1.0/24'

@description('Jumpbox VNet ID - DNS Zone 링크 및 Spoke↔Jumpbox 직접 Peering에 사용 (비어있으면 생략)')
param jumpboxVnetId string = ''

@description('Jumpbox VNet 리소스 그룹 (Spoke↔Jumpbox Peering용, VNet Peering은 transitive하지 않으므로 직접 연결 필수)')
param jumpboxVnetResourceGroup string = ''

@description('Jumpbox VNet 이름 (Spoke↔Jumpbox Peering용)')
param jumpboxVnetName string = ''

@description('모든 리소스에 적용할 태그')
param tags object = {
  Environment: environmentName
  Project: 'AI-Foundry-Classic-ManagedVNet'
  ManagedBy: 'Bicep'
}

// =============================================================================
// 변수 - 리소스 이름에 사용할 프리픽스
// =============================================================================

// 환경별로 고유한 리소스 이름 생성 (예: aifoundry-classic-dev)
var namePrefix = 'aifoundry-classic-${environmentName}'

// =============================================================================
// 리소스 그룹 생성
// subscription 스코프 배포이므로 RG를 직접 생성합니다.
// =============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// [1] 네트워킹 모듈 - Spoke VNet + Hub Peering + Jumpbox Peering + Private DNS Zones
// 가장 먼저 배포되어야 PE 서브넷과 DNS Zone을 사용할 수 있습니다.
// =============================================================================

module networking 'networking/main.bicep' = {
  scope: rg
  name: 'networking-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    vnetAddressPrefix: vnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
    hubVnetId: hubVnetId
    hubVnetResourceGroup: hubVnetResourceGroup
    hubVnetName: hubVnetName
    jumpboxVnetId: jumpboxVnetId
    jumpboxVnetResourceGroup: jumpboxVnetResourceGroup
    jumpboxVnetName: jumpboxVnetName
    tags: tags
  }
}

// =============================================================================
// [2] 종속 리소스 모듈 - Storage Account, Key Vault
// Hub가 내부적으로 사용하는 필수 리소스입니다.
// =============================================================================

module dependentResources 'dependent-resources/main.bicep' = {
  scope: rg
  name: 'dependent-resources-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

// =============================================================================
// [3] AI Foundry 모듈 - Hub + Project + OpenAI + RBAC
// Classic Hub(kind:Hub)와 Managed VNet을 구성하고 OpenAI 모델을 배포합니다.
// =============================================================================

module aiFoundry 'ai-foundry/main.bicep' = {
  scope: rg
  name: 'ai-foundry-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    managedVnetIsolationMode: managedVnetIsolationMode
    storageAccountId: dependentResources.outputs.storageAccountId
    keyVaultId: dependentResources.outputs.keyVaultId
    searchServiceId: dependentResources.outputs.searchServiceId
    searchServiceName: dependentResources.outputs.searchServiceName
    searchServicePrincipalId: dependentResources.outputs.searchServicePrincipalId
    tags: tags
  }
}

// =============================================================================
// [4] Private Endpoints 모듈 - Storage, Key Vault, OpenAI → Spoke VNet
// 각 리소스에 대한 PE를 Spoke VNet의 PE 서브넷에 생성하고 DNS Zone과 연결합니다.
// AI Foundry 모듈 완료 후 배포되어야 OpenAI 리소스 ID를 참조할 수 있습니다.
// =============================================================================

module privateEndpoints 'private-endpoints/main.bicep' = {
  scope: rg
  name: 'private-endpoints-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    storageAccountId: dependentResources.outputs.storageAccountId
    keyVaultId: dependentResources.outputs.keyVaultId
    openAiAccountId: aiFoundry.outputs.openAiAccountId
    hubId: aiFoundry.outputs.hubId
    searchServiceId: dependentResources.outputs.searchServiceId
    privateDnsZoneIds: networking.outputs.privateDnsZoneIds
    tags: tags
  }
}

// =============================================================================
// 출력값 - 배포 후 확인용
// az deployment sub show --name <deployment-name> --query properties.outputs
// =============================================================================

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id

output vnetId string = networking.outputs.vnetId
output vnetName string = networking.outputs.vnetName

output hubName string = aiFoundry.outputs.hubName
output hubId string = aiFoundry.outputs.hubId
output projectName string = aiFoundry.outputs.projectName
output openAiAccountName string = aiFoundry.outputs.openAiAccountName
output openAiEndpoint string = aiFoundry.outputs.openAiEndpoint

output storageAccountName string = dependentResources.outputs.storageAccountName
output keyVaultName string = dependentResources.outputs.keyVaultName
output searchServiceName string = dependentResources.outputs.searchServiceName
