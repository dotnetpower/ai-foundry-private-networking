# =============================================================================
# Korea Central Jumpbox with Azure Bastion
# 개발자 PC 역할의 Jumpbox + Python 개발 환경 자동 구성
# =============================================================================

# Korea Central Jumpbox VNet
resource "azurerm_virtual_network" "jumpbox" {
  name                = "vnet-jumpbox-krc"
  resource_group_name = var.resource_group_name
  location            = var.jumpbox_location
  address_space       = ["10.1.0.0/16"]
  tags                = var.tags
}

# Jumpbox Subnet
resource "azurerm_subnet" "jumpbox" {
  name                 = "snet-jumpbox"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.jumpbox.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Azure Bastion Subnet (이름은 반드시 AzureBastionSubnet)
resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.jumpbox.name
  address_prefixes     = ["10.1.255.0/26"]
}

# NSG for Jumpbox Subnet (Bastion에서만 접근 허용)
resource "azurerm_network_security_group" "jumpbox" {
  name                = "nsg-jumpbox-krc"
  resource_group_name = var.resource_group_name
  location            = var.jumpbox_location
  tags                = var.tags

  # Allow RDP from Bastion Subnet only
  security_rule {
    name                       = "AllowRDPFromBastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.1.255.0/26"
    destination_address_prefix = "*"
  }

  # Allow SSH from Bastion Subnet only
  security_rule {
    name                       = "AllowSSHFromBastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.1.255.0/26"
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow outbound to East US VNet (AI Foundry, APIM)
  security_rule {
    name                       = "AllowEastUSVNet"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "10.0.0.0/16"
  }

  # Allow outbound to Internet (패키지 설치용)
  security_rule {
    name                       = "AllowInternet"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Associate NSG with Jumpbox Subnet
resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  subnet_id                 = azurerm_subnet.jumpbox.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}

# =============================================================================
# Azure Bastion
# =============================================================================

# Public IP for Bastion
resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-bastion-krc"
  resource_group_name = var.resource_group_name
  location            = var.jumpbox_location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Azure Bastion Host
resource "azurerm_bastion_host" "main" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bastion-jumpbox-krc"
  resource_group_name = var.resource_group_name
  location            = var.jumpbox_location
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  # Native client 지원 (az network bastion rdp/ssh 명령어 사용 가능)
  tunneling_enabled  = true
  ip_connect_enabled = true
}

# =============================================================================
# VNet Peering
# =============================================================================

# VNet Peering: Korea Central -> East US
resource "azurerm_virtual_network_peering" "jumpbox_to_main" {
  name                      = "peer-jumpbox-to-main"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.jumpbox.name
  remote_virtual_network_id = var.main_vnet_id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# VNet Peering: East US -> Korea Central
resource "azurerm_virtual_network_peering" "main_to_jumpbox" {
  name                      = "peer-main-to-jumpbox"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = var.main_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.jumpbox.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# =============================================================================
# Windows Jumpbox (개발자 PC - GUI 환경)
# =============================================================================

# Network Interface for Windows Jumpbox (공인 IP 없음)
resource "azurerm_network_interface" "windows" {
  name                = "nic-jumpbox-windows-krc"
  resource_group_name = var.resource_group_name
  location            = var.jumpbox_location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  name                = "vm-jb-win-krc"
  computer_name       = "devpc-win"
  resource_group_name = var.resource_group_name
  location            = var.jumpbox_location
  size                = "Standard_D4s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.windows.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-23h2-pro"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Windows Python 환경 설치 (Custom Script Extension)
# Chocolatey 설치 후 PATH 갱신이 필요하므로 스크립트를 두 단계로 분리
resource "azurerm_virtual_machine_extension" "windows_python" {
  name                 = "install-python-env"
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')); $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); refreshenv; C:\\ProgramData\\chocolatey\\bin\\choco.exe install python311 vscode git azure-cli -y\""
    }
  SETTINGS

  tags = var.tags
}

# =============================================================================
# Linux Jumpbox (개발자 PC - CLI/터미널 환경)
# =============================================================================

# Network Interface for Linux Jumpbox (공인 IP 없음)
resource "azurerm_network_interface" "linux" {
  name                = "nic-jumpbox-linux-krc"
  resource_group_name = var.resource_group_name
  location            = var.jumpbox_location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Linux Virtual Machine with cloud-init
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "vm-jumpbox-linux-krc"
  computer_name                   = "devpc-linux"
  resource_group_name             = var.resource_group_name
  location                        = var.jumpbox_location
  size                            = "Standard_D4s_v3"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  tags                            = var.tags

  network_interface_ids = [
    azurerm_network_interface.linux.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  # Cloud-init으로 Python 환경 자동 설치
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - python3.11
      - python3.11-venv
      - python3-pip
      - git
      - curl
      - jq
      - vim
      - tmux
      - htop

    runcmd:
      # Azure CLI 설치
      - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
      
      # Python 가상환경 생성 및 패키지 설치
      - python3.11 -m venv /opt/ai-dev-env
      - /opt/ai-dev-env/bin/pip install --upgrade pip
      - /opt/ai-dev-env/bin/pip install openai azure-identity azure-ai-projects azure-ai-inference requests ipython jupyter
      
      # 사용자 환경에 가상환경 자동 활성화 추가
      - echo 'source /opt/ai-dev-env/bin/activate' >> /etc/profile.d/ai-dev.sh
      - chmod +x /etc/profile.d/ai-dev.sh
      
      # 샘플 코드 디렉토리 생성
      - mkdir -p /home/${var.admin_username}/ai-samples
      - chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/ai-samples

    final_message: "AI Development Environment Ready!"
  EOF
  )
}

# =============================================================================
# Private DNS Zone Links (Korea Central VNet에 연결)
# East US의 Private DNS Zone을 Korea Central VNet에서도 해석 가능하게 함
# =============================================================================

resource "azurerm_private_dns_zone_virtual_network_link" "apim_krc" {
  name                  = "link-apim-krc"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.azure-api.net"
  virtual_network_id    = azurerm_virtual_network.jumpbox.id
  tags                  = var.tags

  depends_on = [var.private_dns_zone_ids]
}

resource "azurerm_private_dns_zone_virtual_network_link" "azureml_krc" {
  name                  = "link-azureml-krc"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.api.azureml.ms"
  virtual_network_id    = azurerm_virtual_network.jumpbox.id
  tags                  = var.tags

  depends_on = [var.private_dns_zone_ids]
}

resource "azurerm_private_dns_zone_virtual_network_link" "notebooks_krc" {
  name                  = "link-notebooks-krc"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.notebooks.azure.net"
  virtual_network_id    = azurerm_virtual_network.jumpbox.id
  tags                  = var.tags

  depends_on = [var.private_dns_zone_ids]
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_krc" {
  name                  = "link-blob-krc"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.blob.core.windows.net"
  virtual_network_id    = azurerm_virtual_network.jumpbox.id
  tags                  = var.tags

  depends_on = [var.private_dns_zone_ids]
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault_krc" {
  name                  = "link-vault-krc"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.vaultcore.azure.net"
  virtual_network_id    = azurerm_virtual_network.jumpbox.id
  tags                  = var.tags

  depends_on = [var.private_dns_zone_ids]
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai_krc" {
  name                  = "link-openai-krc"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.openai.azure.com"
  virtual_network_id    = azurerm_virtual_network.jumpbox.id
  tags                  = var.tags

  depends_on = [var.private_dns_zone_ids]
}

resource "azurerm_private_dns_zone_virtual_network_link" "cogservices_krc" {
  name                  = "link-cogservices-krc"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.cognitiveservices.azure.com"
  virtual_network_id    = azurerm_virtual_network.jumpbox.id
  tags                  = var.tags

  depends_on = [var.private_dns_zone_ids]
}

