// =============================================================================
// Jumpbox Module - Linux/Windows VMs, Azure Bastion, NAT Gateway
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

@description('Deploy Linux Jumpbox')
param deployLinuxJumpbox bool = false

@description('Deploy Windows Jumpbox')
param deployWindowsJumpbox bool = true

@description('VM size for Jumpbox VMs')
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
// Linux Jumpbox VM
// =============================================================================

resource linuxNic 'Microsoft.Network/networkInterfaces@2023-11-01' = if (deployLinuxJumpbox) {
  name: 'nic-${namePrefix}-jumpbox-linux'
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

resource linuxVm 'Microsoft.Compute/virtualMachines@2024-03-01' = if (deployLinuxJumpbox) {
  name: 'vm-${namePrefix}-jumpbox-linux'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'jumpbox-linux'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
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
          id: linuxNic.id
        }
      ]
    }
  }
}

// Linux VM Custom Script Extension for Dev Environment Setup
resource linuxVmExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if (deployLinuxJumpbox) {
  parent: linuxVm
  name: 'setup-dev-environment'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64('''
#!/bin/bash
set -e

# Update and install packages
apt-get update
apt-get install -y python3.11 python3.11-venv python3-pip git jq vim tmux curl

# Create Python venv
python3.11 -m venv /opt/ai-dev-env
source /opt/ai-dev-env/bin/activate
pip install --upgrade pip
pip install openai azure-identity azure-search-documents azure-storage-blob

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Set permissions
chmod -R 755 /opt/ai-dev-env
chown -R azureuser:azureuser /opt/ai-dev-env

echo "Development environment setup complete!"
''')
    }
  }
}

// =============================================================================
// Windows Jumpbox VM
// =============================================================================

resource windowsNic 'Microsoft.Network/networkInterfaces@2023-11-01' = if (deployWindowsJumpbox) {
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

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = if (deployWindowsJumpbox) {
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

output linuxVmId string = deployLinuxJumpbox ? linuxVm.id : ''
output linuxVmName string = deployLinuxJumpbox ? linuxVm.name : ''
output linuxVmPrivateIp string = deployLinuxJumpbox ? linuxNic.properties.ipConfigurations[0].properties.privateIPAddress : ''

output windowsVmId string = deployWindowsJumpbox ? windowsVm.id : ''
output windowsVmName string = deployWindowsJumpbox ? windowsVm.name : ''
output windowsVmPrivateIp string = deployWindowsJumpbox ? windowsNic.properties.ipConfigurations[0].properties.privateIPAddress : ''
