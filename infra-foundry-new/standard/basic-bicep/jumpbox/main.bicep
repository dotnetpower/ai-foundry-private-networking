// =============================================================================
// Jumpbox Module - Windows VM (Public IP + RDP)
// =============================================================================

@description('Location for all resources')
param location string

@description('Resource name prefix')
param namePrefix string

@description('Jumpbox subnet ID')
param jumpboxSubnetId string

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('Tags')
param tags object = {}

// =============================================================================
// Public IP for Windows Jumpbox
// =============================================================================

resource windowsPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
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
// Windows Jumpbox (Windows 11 Pro)
// =============================================================================

resource windowsNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${namePrefix}-windows'
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
          publicIPAddress: {
            id: windowsPip.id
          }
        }
      }
    ]
  }
}

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'vm-${namePrefix}-win'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
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
          storageAccountType: 'Standard_LRS'
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

output windowsVmPrivateIp string = windowsNic.properties.ipConfigurations[0].properties.privateIPAddress
output windowsVmPublicIp string = windowsPip.properties.ipAddress
