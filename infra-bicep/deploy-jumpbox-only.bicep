// =============================================================================
// Jumpbox Only Deployment for existing VNet
// =============================================================================

targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = 'swedencentral'

@description('Resource name prefix')
param namePrefix string = 'aifoundry-dev'

@description('Existing VNet name')
param vnetName string = 'vnet-aifoundry-dev'

@description('Jumpbox Subnet address prefix')
param jumpboxSubnetAddressPrefix string = '192.168.2.0/24'

@description('Bastion Subnet address prefix')
param bastionSubnetAddressPrefix string = '192.168.255.0/26'

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('VM size for Jumpbox VMs')
param vmSize string = 'Standard_D4s_v3'

param tags object = {
  Environment: 'dev'
  Project: 'AIFoundry'
  DeployedBy: 'Bicep'
}

// =============================================================================
// Existing VNet Reference
// =============================================================================

resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

// =============================================================================
// Jumpbox Subnet 
// =============================================================================

resource jumpboxSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: existingVnet
  name: 'snet-jumpbox'
  properties: {
    addressPrefix: jumpboxSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// =============================================================================
// Bastion Subnet
// =============================================================================

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: existingVnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    jumpboxSubnet
  ]
}

// =============================================================================
// NAT Gateway for Outbound
// =============================================================================

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${namePrefix}-nat'
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

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'nat-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
}

// =============================================================================
// Azure Bastion
// =============================================================================

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${namePrefix}-bastion'
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

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bastion-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: bastionSubnet.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Windows Jumpbox NIC
// =============================================================================

resource windowsNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${namePrefix}-win'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: jumpboxSubnet.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Windows Jumpbox VM (Windows 11 Pro)
// =============================================================================

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'vm-jumpbox-win'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'jumpbox-win'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-jumpbox-win'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: windowsNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

output bastionName string = bastionHost.name
output vmName string = windowsVm.name
output vmPrivateIp string = windowsNic.properties.ipConfigurations[0].properties.privateIPAddress
