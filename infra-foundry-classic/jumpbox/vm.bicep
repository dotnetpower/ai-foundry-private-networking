// =============================================================================
// Jumpbox VM 모듈 - VNet + NSG + VM + Hub VNet Peering
// =============================================================================
// On-premises 시뮬레이션용 Windows VM을 생성합니다.
// 자체 VNet에 배포되며 Hub VNet과 양방향 Peering을 구성합니다.
// RDP 접속을 위한 Public IP와 NSG 규칙이 포함됩니다.
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Jumpbox VNet address prefix')
param jumpboxVnetAddressPrefix string

@description('Jumpbox subnet address prefix')
param jumpboxSubnetAddressPrefix string

@description('Allowed source IP for RDP')
param allowedRdpSourceIP string

@description('Hub VNet resource ID for peering')
param hubVnetId string

@description('Hub VNet resource group name')
param hubVnetResourceGroup string

@description('Hub VNet name')
param hubVnetName string

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('VM size')
param vmSize string

@description('Tags')
param tags object = {}

// =============================================================================
// NSG - RDP access
// =============================================================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-${namePrefix}-jumpbox'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: allowedRdpSourceIP
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowInternetOutbound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

// =============================================================================
// VNet (Simulates on-premises network)
// =============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-${namePrefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        jumpboxVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-jumpbox'
        properties: {
          addressPrefix: jumpboxSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// VNet Peering: Jumpbox (on-prem) → Hub
// =============================================================================

resource peeringToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnet
  name: 'peer-onprem-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
  }
}

// =============================================================================
// VNet Peering: Hub → Jumpbox (on-prem) — cross-RG peering
// =============================================================================

module hubToOnpremPeering 'hub-peering.bicep' = {
  scope: resourceGroup(hubVnetResourceGroup)
  name: 'hub-to-onprem-peering'
  params: {
    hubVnetName: hubVnetName
    remoteVnetId: vnet.id
    peeringName: 'peer-hub-to-onprem'
  }
}

// =============================================================================
// Public IP
// =============================================================================

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-${namePrefix}-jumpbox'
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
// NIC
// =============================================================================

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${namePrefix}-jumpbox'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Windows VM
// =============================================================================

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'vm-${namePrefix}-jumpbox'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'onprem-pc'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

output vmId string = windowsVm.id
output vmName string = windowsVm.name
output publicIpAddress string = publicIp.properties.ipAddress
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vnetId string = vnet.id
