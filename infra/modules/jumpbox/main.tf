# =============================================================================
# Jumpbox Module - Sweden Central 단일 리전
# Linux Jumpbox + Azure Bastion (동일 VNet 내)
# =============================================================================

# =============================================================================
# Azure Bastion
# =============================================================================

# Public IP for Bastion
resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Azure Bastion Host
resource "azurerm_bastion_host" "main" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bastion-aifoundry"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  # Native client 지원 (az network bastion ssh 명령어 사용 가능)
  tunneling_enabled  = true
  ip_connect_enabled = true
}

# =============================================================================
# Linux Jumpbox (개발자 PC - CLI/터미널 환경)
# =============================================================================

# Network Interface for Linux Jumpbox (공인 IP 없음)
resource "azurerm_network_interface" "linux" {
  name                = "nic-jumpbox-linux"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.jumpbox_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# Linux Virtual Machine with cloud-init
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "vm-jumpbox-linux"
  computer_name                   = "devpc-linux"
  resource_group_name             = var.resource_group_name
  location                        = var.location
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
    disk_size_gb         = 128
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
# Windows Jumpbox (Portal 접속용 - GUI 환경)
# =============================================================================

# Network Interface for Windows Jumpbox (공인 IP 없음)
resource "azurerm_network_interface" "windows" {
  count               = var.enable_windows_jumpbox ? 1 : 0
  name                = "nic-jumpbox-windows"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.jumpbox_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  count               = var.enable_windows_jumpbox ? 1 : 0
  name                = "vm-jumpbox-win"
  computer_name       = "devpc-win"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_D4s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.windows[0].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}
