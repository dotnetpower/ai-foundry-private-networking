// =============================================================================
// Monitoring Module - Log Analytics + Application Insights
// =============================================================================
// Hosted Agent의 OpenTelemetry 트레이스, 메트릭, 로그 수집
// =============================================================================

@description('Location for all resources')
param location string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Tags to apply to all resources')
param tags object = {}

// Short suffix for resource names
var shortSuffix = take(uniqueSuffix, 8)

// =============================================================================
// Log Analytics Workspace
// =============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${shortSuffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// =============================================================================
// Application Insights (Workspace-based)
// =============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${shortSuffix}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
