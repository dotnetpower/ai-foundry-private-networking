// =============================================================================
// Container Registry Module - Azure Container Registry for Hosted Agents
// =============================================================================
// Hosted Agent 컨테이너 이미지를 저장할 ACR
// Project Managed Identity에 AcrPull 역할 자동 부여
// =============================================================================

@description('Location for all resources')
param location string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Tags to apply to all resources')
param tags object = {}

@description('ACR SKU')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

@description('Foundry Project system-assigned managed identity principal ID')
param projectPrincipalId string

// =============================================================================
// Azure Container Registry
// =============================================================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${uniqueSuffix}'
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// =============================================================================
// RBAC: AcrPull for Project Managed Identity
// Hosted Agent가 ACR에서 이미지를 Pull 할 수 있도록 권한 부여
// Role: AcrPull (7f951dda-4ed3-4680-a7ca-43fe172d538d)
// =============================================================================

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, projectPrincipalId, acrPullRoleId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: projectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output acrId string = containerRegistry.id
output acrName string = containerRegistry.name
output acrLoginServer string = containerRegistry.properties.loginServer
