// =============================================================================
// Application Gateway - 온프레미스 리소스 접근용 (Managed VNet)
// =============================================================================
// Managed VNet에서는 VPN/ExpressRoute 직접 연결이 불가하므로,
// Application Gateway를 프록시로 사용하여 온프레미스 리소스에 접근합니다.
//
// 아키텍처:
//   Managed VNet (Agent) → outbound rule PE → App Gateway → 온프레미스
//
// ⚠️ 배포 후 Backend Pool 구성이 필요합니다:
//   - Azure Portal > Application Gateway > Backend pools
//   - 온프레미스 리소스 IP/FQDN을 Backend Pool에 추가
//   - Health probe 및 HTTP settings 구성
//   - Managed VNet outbound rule 추가 (CLI)
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Application Gateway subnet ID')
param appGatewaySubnetId string

@description('Application Gateway SKU tier')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuTier string = 'Standard_v2'

@description('Application Gateway capacity (instance count)')
@minValue(1)
@maxValue(10)
param capacity int = 1

@description('Tags')
param tags object = {}

// =============================================================================
// Public IP (Application Gateway v2 필수)
// =============================================================================

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-${namePrefix}-appgw'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// =============================================================================
// Application Gateway
// =============================================================================

resource appGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: 'appgw-${namePrefix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuTier
      tier: skuTier
      capacity: capacity
    }
    gatewayIPConfigurations: [
      {
        name: 'gatewayIpConfig'
        properties: {
          subnet: {
            id: appGatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendPublicIp'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-443'
        properties: {
          port: 443
        }
      }
      {
        name: 'port-80'
        properties: {
          port: 80
        }
      }
    ]
    // =========================================================================
    // Placeholder Backend Pool
    // ⚠️ 배포 후 Azure Portal에서 온프레미스 리소스 IP/FQDN으로 교체 필요
    // =========================================================================
    backendAddressPools: [
      {
        name: 'onprem-backend-pool'
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'onprem-http-settings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
        }
      }
    ]
    httpListeners: [
      {
        name: 'http-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'appgw-${namePrefix}', 'frontendPublicIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'appgw-${namePrefix}', 'port-80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'onprem-routing-rule'
        properties: {
          priority: 100
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'appgw-${namePrefix}', 'http-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'appgw-${namePrefix}', 'onprem-backend-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'appgw-${namePrefix}', 'onprem-http-settings')
          }
        }
      }
    ]
    // Private Link Configuration (Managed VNet PE 연결용)
    privateLinkConfigurations: [
      {
        name: 'privatelink-config'
        properties: {
          ipConfigurations: [
            {
              name: 'privatelink-ipconfig'
              properties: {
                subnet: {
                  id: appGatewaySubnetId
                }
                privateIPAllocationMethod: 'Dynamic'
                primary: true
              }
            }
          ]
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

output appGatewayId string = appGateway.id
output appGatewayName string = appGateway.name
output appGatewayPublicIp string = publicIp.properties.ipAddress
