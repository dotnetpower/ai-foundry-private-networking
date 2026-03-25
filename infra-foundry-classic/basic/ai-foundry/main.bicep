// =============================================================================
// AI Foundry 모듈 - Classic Hub + Project + Azure OpenAI + RBAC
// =============================================================================
// Microsoft.MachineLearningServices/workspaces (kind: Hub) 리소스를 사용합니다.
// Hub는 Managed VNet을 자동으로 생성하고 연결된 리소스에 대한 PE를 관리합니다.
// OpenAI API 버전: 2024-10-01 (GA - preview 사용 금지)
// =============================================================================

@description('리소스 배포 위치')
param location string

@description('리소스 이름 프리픽스')
param namePrefix string

@description('전역적으로 고유한 이름 생성용 접미사 (resourceGroup().id 기반)')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Managed VNet 격리 모드')
@allowed([
  'AllowInternetOutbound'
  'AllowOnlyApprovedOutbound'
])
param managedVnetIsolationMode string = 'AllowInternetOutbound'

@description('Storage Account 리소스 ID (Hub의 기본 데이터 저장소로 사용)')
param storageAccountId string

@description('Key Vault 리소스 ID (Hub의 비밀 관리용)')
param keyVaultId string

@description('AI Search 리소스 ID (RAG 벡터 검색용)')
param searchServiceId string

@description('AI Search 리소스 이름 (Hub Connection용)')
param searchServiceName string

@description('AI Search Managed Identity Principal ID (RBAC용)')
param searchServicePrincipalId string

@description('모든 리소스에 적용할 태그')
param tags object = {}

// 이름 충돌 방지용 짧은 접미사 (8자)
var shortSuffix = take(uniqueSuffix, 8)

// =============================================================================
// Azure OpenAI (Cognitive Services Account)
// Classic Hub에서는 kind: 'OpenAI'를 사용 (New Foundry는 kind: 'AIServices')
// publicNetworkAccess: Enabled - Hub가 Managed VNet PE를 생성하려면 초기에 public 접근 필요
// =============================================================================

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'oai-${shortSuffix}'
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: 'oai-${shortSuffix}'
    publicNetworkAccess: 'Enabled' // Must be Enabled initially for Hub to create managed PE
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false
  }
}

// =============================================================================
// GPT-4o 모델 배포
// GlobalStandard SKU로 Sweden Central에서 지원됨
// =============================================================================

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAiAccount
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

// =============================================================================
// 텍스트 임베딩 모델 배포 (RAG 벡터 검색용)
// text-embedding-ada-002: 1536차원
// =============================================================================

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAiAccount
  name: 'text-embedding-ada-002'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
  }
  dependsOn: [
    gpt4oDeployment
  ]
}

// =============================================================================
// AI Hub (Classic Foundry - MachineLearningServices workspace kind: Hub)
// Managed VNet을 사용하여 내부 컴퓨팅 네트워크를 자동 관리합니다.
// managedNetwork.outboundRules에 OpenAI PE 규칙을 추가하여 내부 연결 구성
// publicNetworkAccess: Enabled - Portal 접근을 위해 초기에는 활성화
// PE 프로비저닝 완료 후 Disabled로 전환 가능
// =============================================================================

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: 'hub-${shortSuffix}'
  location: location
  tags: tags
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'AI Foundry Hub (${namePrefix})'
    description: 'Classic AI Foundry Hub with Managed VNet'
    storageAccount: storageAccountId
    keyVault: keyVaultId
    publicNetworkAccess: 'Enabled' // Enabled for Portal access; PE provides private path for Jumpbox
    managedNetwork: {
      isolationMode: managedVnetIsolationMode
      outboundRules: {
        openai: {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: openAiAccount.id
            subresourceTarget: 'account'
            sparkEnabled: false
          }
        }
        search: {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: searchServiceId
            subresourceTarget: 'searchService'
            sparkEnabled: false
          }
        }
      }
    }
  }
  dependsOn: [
    embeddingDeployment
  ]
}

// =============================================================================
// AI Project (Classic Foundry - Hub 하위 프로젝트)
// Hub의 리소스와 네트워크를 상속받아 사용합니다.
// =============================================================================

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: 'proj-${shortSuffix}'
  location: location
  tags: tags
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'AI Foundry Project (${namePrefix})'
    description: 'Classic AI Foundry Project'
    hubResourceId: aiHub.id
  }
}

// =============================================================================
// Hub Connection - Azure OpenAI 연결
// Hub에서 OpenAI 리소스를 사용하기 위한 AAD 인증 연결
// =============================================================================

resource openAiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: aiHub
  name: 'aoai-connection'
  properties: {
    category: 'AzureOpenAI'
    target: openAiAccount.properties.endpoint
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: openAiAccount.id
    }
  }
}

// =============================================================================
// RBAC 역할 할당
// Hub MI에 OpenAI Contributor, Storage Blob Data Contributor, Key Vault Admin 부여
// identity 기반 인증 시 Storage File Data Privileged Contributor도 필요
// =============================================================================

// Cognitive Services OpenAI Contributor for Hub MI on OpenAI account
var cognitiveServicesOpenAiContributorRoleId = 'a001fd3d-188f-4b5d-821b-7da978bf7442'
resource hubOpenAiContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAiAccount.id, aiHub.id, cognitiveServicesOpenAiContributorRoleId)
  scope: openAiAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAiContributorRoleId)
    principalId: aiHub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor for Hub MI
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource hubStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, aiHub.id, storageBlobDataContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: aiHub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Administrator for Hub MI
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
resource hubKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, aiHub.id, keyVaultAdministratorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
    principalId: aiHub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// AI Search RBAC — Hub MI, Project MI, AI Search MI
// =============================================================================

// 참조용 AI Search 리소스
resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: searchServiceName
}

// Search Index Data Contributor for Hub MI on AI Search
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
resource hubSearchIndexRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, aiHub.id, searchIndexDataContributorRoleId)
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: aiHub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Index Data Contributor for Project MI
resource projectSearchIndexRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, aiProject.id, searchIndexDataContributorRoleId)
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Service Contributor for Hub MI
var searchServiceContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
resource hubSearchServiceRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, aiHub.id, searchServiceContributorRoleId)
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: aiHub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Service Contributor for Project MI
resource projectSearchServiceRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchServiceId, aiProject.id, searchServiceContributorRoleId)
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services OpenAI User for AI Search MI (integrated vectorizer에서 임베딩 생성)
var cognitiveServicesOpenAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource searchOpenAiUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAiAccount.id, searchServiceId, cognitiveServicesOpenAiUserRoleId)
  scope: openAiAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAiUserRoleId)
    principalId: searchServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Reader for AI Search MI (인덱서에서 Blob 읽기)
var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
resource searchStorageReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, searchServiceId, storageBlobDataReaderRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: searchServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// Hub Connection — AI Search 연결
// =============================================================================

resource searchConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: aiHub
  name: 'search-connection'
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${searchServiceName}.search.windows.net'
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: searchServiceId
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

output hubId string = aiHub.id
output hubName string = aiHub.name
output hubPrincipalId string = aiHub.identity.principalId

output projectId string = aiProject.id
output projectName string = aiProject.name

output openAiAccountId string = openAiAccount.id
output openAiAccountName string = openAiAccount.name
output openAiEndpoint string = openAiAccount.properties.endpoint
