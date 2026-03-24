// =============================================================================
// Jumpbox Module - Windows VM, Azure Bastion, NAT Gateway
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

@description('Jumpbox Subnet ID')
param jumpboxSubnetId string

@description('Bastion Subnet ID')
param bastionSubnetId string

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('VM size for Jumpbox VM')
param vmSize string = 'Standard_D4s_v3'

// =============================================================================
// NAT Gateway for Jumpbox Outbound
// =============================================================================

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
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

resource natGateway 'Microsoft.Network/natGateways@2023-11-01' = {
  name: 'nat-${namePrefix}-jumpbox'
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

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
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

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: 'bastion-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    enableIpConnect: true
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// Windows Jumpbox VM
// =============================================================================

resource windowsNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${namePrefix}-jumpbox-win'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: jumpboxSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'vm-${namePrefix}-jumpbox-win'
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
          id: windowsNic.id
        }
      ]
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

output bastionId string = bastion.id
output bastionName string = bastion.name

output natGatewayId string = natGateway.id

output windowsVmId string = windowsVm.id
output windowsVmName string = windowsVm.name
output windowsVmPrivateIp string = windowsNic.properties.ipConfigurations[0].properties.privateIPAddress
