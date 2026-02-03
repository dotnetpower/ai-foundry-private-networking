# AI Foundry 접속 완벽 가이드

## 목차

1. [Azure Bastion을 통한 Jumpbox 접속](#1-azure-bastion을-통한-jumpbox-접속)
2. [Jumpbox에서 AI Foundry 접속](#2-jumpbox에서-ai-foundry-접속)
3. [네트워크 연결 확인 및 진단](#3-네트워크-연결-확인-및-진단)
4. [문제 해결 (Troubleshooting)](#4-문제-해결-troubleshooting)
5. [고급 진단](#5-고급-진단)

---

## 1. Azure Bastion을 통한 Jumpbox 접속

### 1.1 Azure Portal을 통한 접속 (권장)

#### Windows Jumpbox 접속

1. **Azure Portal 로그인**
   - https://portal.azure.com 접속
   - 적절한 구독 선택

2. **리소스 그룹 이동**
   - 검색창에 `rg-aifoundry-20260128` 입력
   - 리소스 그룹 클릭

3. **Windows Jumpbox VM 선택**
   - 리소스 목록에서 `vm-jb-win-krc` 클릭
   - 또는 검색창에서 직접 검색

4. **Bastion 연결 시작**
   ```
   좌측 메뉴 → "연결" (Connect) → "Bastion" 선택
   ```

5. **자격 증명 입력**
   - **사용자 이름**: `azureuser` (기본값)
   - **인증 방법**: "VM 암호" 선택
   - **암호**: Terraform 배포 시 설정한 패스워드 입력
   
   > ⚠️ **보안 참고**: 패스워드는 환경 변수(`TF_VAR_jumpbox_admin_password`)로 설정되어야 합니다.

6. **연결 버튼 클릭**
   - "연결" 버튼 클릭
   - 새 브라우저 탭에서 Windows 원격 데스크톱 세션 시작
   - 최대 30초 소요

#### Linux Jumpbox 접속

1. **Azure Portal에서 Linux VM 선택**
   - 리소스 그룹: `rg-aifoundry-20260128`
   - VM: `vm-jumpbox-linux-krc`

2. **Bastion 연결**
   ```
   좌측 메뉴 → "연결" → "Bastion"
   ```

3. **자격 증명 입력**
   - **사용자 이름**: `azureuser`
   - **인증 방법**: "VM 암호" 선택
   - **암호**: Terraform 배포 시 설정한 패스워드 입력

4. **연결**
   - 브라우저 기반 SSH 터미널 세션 시작

### 1.2 Azure CLI를 통한 접속 (Native Client)

Azure Bastion Standard SKU는 Native RDP/SSH 클라이언트 지원을 제공합니다.

#### Windows RDP (로컬 RDP 클라이언트 사용)

```bash
# 1. Azure CLI 로그인
az login
az account set --subscription "<구독-ID 또는 이름>"

# 2. Windows VM Resource ID 가져오기
VM_ID=$(az vm show \
  --resource-group rg-aifoundry-20260128 \
  --name vm-jb-win-krc \
  --query id -o tsv)

# 3. Bastion Native RDP 연결
az network bastion rdp \
  --name bastion-jumpbox-krc \
  --resource-group rg-aifoundry-20260128 \
  --target-resource-id $VM_ID
```

**입력 프롬프트:**
- Username: `azureuser`
- Password: `<Terraform 배포 시 설정한 패스워드>`

#### Linux SSH (로컬 SSH 클라이언트 사용)

```bash
# 1. Linux VM Resource ID 가져오기
VM_ID=$(az vm show \
  --resource-group rg-aifoundry-20260128 \
  --name vm-jumpbox-linux-krc \
  --query id -o tsv)

# 2. Bastion Native SSH 연결
az network bastion ssh \
  --name bastion-jumpbox-krc \
  --resource-group rg-aifoundry-20260128 \
  --target-resource-id $VM_ID \
  --auth-type password \
  --username azureuser
```

### 1.3 연결 문제 해결

#### "Bastion host not found" 오류

**원인**: Bastion 리소스가 배포되지 않았거나 다른 리소스 그룹에 있음

**해결**:
```bash
# Bastion 존재 확인
az network bastion list \
  --resource-group rg-aifoundry-20260128 \
  --query "[].{name:name, provisioningState:provisioningState}" -o table
```

**예상 출력**:
```
Name                   ProvisioningState
---------------------  -------------------
bastion-jumpbox-krc    Succeeded
```

#### "Unable to connect to the target virtual machine" 오류

**원인**: NSG 규칙 또는 VM 방화벽 차단

**해결**:
```bash
# NSG 규칙 확인
az network nsg rule list \
  --resource-group rg-aifoundry-20260128 \
  --nsg-name nsg-jumpbox-krc \
  --query "[?direction=='Inbound' && (destinationPortRange=='3389' || destinationPortRange=='22')].{name:name, priority:priority, access:access, sourceAddressPrefix:sourceAddressPrefix}" -o table
```

**예상 출력** (Bastion 서브넷만 허용):
```
Name                   Priority    Access    SourceAddressPrefix
-------------------    --------    ------    -------------------
AllowRDPFromBastion    100         Allow     10.1.255.0/26
AllowSSHFromBastion    110         Allow     10.1.255.0/26
```

---

## 2. Jumpbox에서 AI Foundry 접속

### 2.1 Windows Jumpbox에서 AI Foundry 접속

#### 방법 1: 웹 브라우저 (권장)

1. **Edge 브라우저 실행**
   - 바탕화면 또는 작업 표시줄에서 Microsoft Edge 실행

2. **AI Foundry 포털 접속**
   ```
   URL: https://ai.azure.com
   ```

3. **Azure 계정 로그인**
   - 회사 또는 Microsoft 계정으로 로그인
   - MFA(다중 인증) 완료 (활성화된 경우)

4. **AI Foundry Hub 선택**
   - 좌측 메뉴 → "All hubs" 또는 "모든 허브"
   - `aihub-foundry` 선택
   - 리전: **East US**

5. **AI Project 열기**
   - Hub 내에서 `aiproj-agents` 프로젝트 선택
   - 또는 좌측 메뉴 → "All projects" → `aiproj-agents`

6. **AI 기능 사용**
   - **Playground**: GPT-4o 모델 테스트
   - **Deployments**: 배포된 모델 확인
   - **Agent Builder**: AI 에이전트 생성
   - **Prompt Flow**: 워크플로우 작성

#### 방법 2: Azure CLI (명령줄)

Windows Jumpbox에는 Azure CLI가 사전 설치되어 있습니다.

```powershell
# PowerShell 또는 CMD 실행

# Azure 로그인
az login --use-device-code

# AI Foundry Hub 정보 확인
az ml workspace show \
  --name aihub-foundry \
  --resource-group rg-aifoundry-20260128 \
  --query "{name:name, location:location, workspaceId:workspaceId}" -o table

# OpenAI 배포 목록 확인
az cognitiveservices account deployment list \
  --name aoai-aifoundry \
  --resource-group rg-aifoundry-20260128 \
  -o table
```

**예상 출력**:
```
Name                      SkuName        SkuCapacity    ProvisioningState
------------------------  -------------  -------------  -------------------
gpt-4o                    GlobalStandard  1              Succeeded
text-embedding-ada-002    Standard        1              Succeeded
```

#### 방법 3: Python SDK

```powershell
# Python 실행
python

# Python 코드 입력
```

```python
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential

# AI Foundry 클라이언트 생성
credential = DefaultAzureCredential()
ml_client = MLClient(
    credential=credential,
    subscription_id="<구독-ID>",
    resource_group_name="rg-aifoundry-20260128",
    workspace_name="aihub-foundry"
)

# 워크스페이스 정보 확인
workspace = ml_client.workspaces.get("aihub-foundry")
print(f"Workspace: {workspace.name}")
print(f"Location: {workspace.location}")
print(f"Description: {workspace.description}")

# Azure OpenAI 연결 확인
connections = ml_client.connections.list()
for conn in connections:
    print(f"Connection: {conn.name} - Type: {conn.type}")
```

### 2.2 Linux Jumpbox에서 AI Foundry 접속

#### 방법 1: curl을 통한 REST API 테스트

```bash
# AI Hub API 엔드포인트 연결 테스트
curl -I https://aihub-foundry.eastus.api.azureml.ms

# Private Endpoint를 통한 연결 확인 (Private IP 반환되어야 함)
nslookup aihub-foundry.eastus.api.azureml.ms
```

**예상 출력**:
```
Server:         168.63.129.16
Address:        168.63.129.16#53

Non-authoritative answer:
Name:   aihub-foundry.eastus.api.azureml.ms
Address: 10.0.1.X  ← Private IP (10.0.1.0/24 범위)
```

#### 방법 2: Azure CLI

```bash
# Azure 로그인 (Device Code 방식)
az login --use-device-code

# AI Foundry Hub 상태 확인
az ml workspace show \
  --name aihub-foundry \
  --resource-group rg-aifoundry-20260128

# Azure OpenAI 엔드포인트 확인
az cognitiveservices account show \
  --name aoai-aifoundry \
  --resource-group rg-aifoundry-20260128 \
  --query "{endpoint:properties.endpoint, location:location, provisioningState:properties.provisioningState}"
```

#### 방법 3: Python SDK (Jupyter Notebook 사용)

Linux Jumpbox에도 Python과 Jupyter가 설치되어 있습니다.

```bash
# Jupyter Notebook 실행 (로컬 포트 포워딩)
jupyter notebook --no-browser --port=8888

# 출력된 토큰 URL 복사 후 Windows Jumpbox 브라우저에서 접속
# 예: http://localhost:8888/?token=...
```

---

## 3. 네트워크 연결 확인 및 진단

### 3.1 기본 연결 테스트 (Windows PowerShell)

```powershell
# 1. 인터넷 연결 확인
Test-NetConnection -ComputerName google.com -Port 443

# 2. Azure Public 엔드포인트 연결
Test-NetConnection -ComputerName ai.azure.com -Port 443

# 3. AI Hub Private Endpoint 연결 (실제 GUID는 배포마다 다름)
# Hub의 Private Endpoint FQDN 확인 필요
$hubEndpoint = "aihub-foundry.eastus.api.azureml.ms"
Test-NetConnection -ComputerName $hubEndpoint -Port 443

# 4. Storage Private Endpoint 연결
Test-NetConnection -ComputerName staifoundry20260128.blob.core.windows.net -Port 443

# 5. OpenAI Private Endpoint 연결
Test-NetConnection -ComputerName aoai-aifoundry.openai.azure.com -Port 443
```

**성공 예시**:
```
ComputerName     : ai.azure.com
RemoteAddress    : 13.107.246.40
RemotePort       : 443
InterfaceAlias   : Ethernet
SourceAddress    : 10.1.1.4
TcpTestSucceeded : True ✅
```

**실패 예시**:
```
WARNING: TCP connect to (aoai-aifoundry.openai.azure.com : 443) failed
TcpTestSucceeded : False ❌
```

### 3.2 DNS 해석 확인 (Windows PowerShell)

```powershell
# 1. Public DNS 해석
nslookup ai.azure.com

# 2. Private Endpoint DNS 해석 - AI Hub
nslookup aihub-foundry.eastus.api.azureml.ms

# 3. Private Endpoint DNS 해석 - Storage Blob
nslookup staifoundry20260128.blob.core.windows.net

# 4. Private Endpoint DNS 해석 - Key Vault
nslookup kv-aif-e8txcj4l.vault.azure.net

# 5. Private Endpoint DNS 해석 - Azure OpenAI
nslookup aoai-aifoundry.openai.azure.com

# 6. Private Endpoint DNS 해석 - AI Search
nslookup srch-aifoundry-7kkykgt6.search.windows.net

# 7. DNS 서버 확인 (Azure VNet DNS 사용 여부)
Get-DnsClientServerAddress -InterfaceAlias Ethernet
```

**올바른 DNS 해석 예시** (Private IP 반환):
```
Server:  AzureVNetDNS
Address: 168.63.129.16

Non-authoritative answer:
Name:    staifoundry20260128.privatelink.blob.core.windows.net
Address: 10.0.1.5  ← Private IP (10.0.1.0/24 범위) ✅
Aliases: staifoundry20260128.blob.core.windows.net
```

**잘못된 DNS 해석 예시** (Public IP 반환):
```
Server:  google-public-dns-a.google.com
Address: 8.8.8.8

Non-authoritative answer:
Name:    blob.bn8prdstr01a.store.core.windows.net
Address: 20.209.123.45  ← Public IP ❌
Aliases: staifoundry20260128.blob.core.windows.net
```

### 3.3 VNet Peering 상태 확인 (Azure CLI - 로컬 또는 Jumpbox)

```bash
# Korea Central → East US Peering 상태
az network vnet peering show \
  --name peer-jumpbox-to-main \
  --resource-group rg-aifoundry-20260128 \
  --vnet-name vnet-jumpbox-krc \
  --query "{name:name, peeringState:peeringState, provisioningState:provisioningState, allowForwardedTraffic:allowForwardedTraffic}" -o table

# East US → Korea Central Peering 상태
az network vnet peering show \
  --name peer-main-to-jumpbox \
  --resource-group rg-aifoundry-20260128 \
  --vnet-name vnet-aifoundry \
  --query "{name:name, peeringState:peeringState, provisioningState:provisioningState, allowForwardedTraffic:allowForwardedTraffic}" -o table
```

**예상 출력** (정상):
```
Name                   PeeringState    ProvisioningState    AllowForwardedTraffic
---------------------  --------------  -------------------  ----------------------
peer-jumpbox-to-main   Connected       Succeeded            True ✅
peer-main-to-jumpbox   Connected       Succeeded            True ✅
```

### 3.4 Private DNS Zone VNet Link 확인

AI Foundry가 정상 작동하려면 **모든 Private DNS Zone이 Korea Central VNet에 연결**되어 있어야 합니다.

```bash
# 모든 DNS Zone의 Korea Central VNet 링크 확인
for zone in \
  privatelink.api.azureml.ms \
  privatelink.notebooks.azure.net \
  privatelink.blob.core.windows.net \
  privatelink.file.core.windows.net \
  privatelink.vaultcore.azure.net \
  privatelink.openai.azure.com \
  privatelink.cognitiveservices.azure.com \
  privatelink.search.windows.net \
  privatelink.azurecr.io \
  privatelink.azure-api.net
do
    echo "=== $zone ==="
    az network private-dns link vnet list \
      --zone-name $zone \
      --resource-group rg-aifoundry-20260128 \
      --query "[?contains(virtualNetwork.id, 'vnet-jumpbox-krc')].{name:name, registrationEnabled:registrationEnabled, provisioningState:provisioningState}" -o table
    echo ""
done
```

**예상 출력** (각 DNS Zone당 1개의 링크):
```
=== privatelink.api.azureml.ms ===
Name                                  RegistrationEnabled    ProvisioningState
------------------------------------  ---------------------  -------------------
link-aihub-jumpbox-krc                False                  Succeeded ✅

=== privatelink.blob.core.windows.net ===
Name                                  RegistrationEnabled    ProvisioningState
------------------------------------  ---------------------  -------------------
link-storage-blob-jumpbox-krc         False                  Succeeded ✅

... (나머지 8개 DNS Zone도 동일)
```

**문제 발견 시** (링크 없음):
```
=== privatelink.openai.azure.com ===
(빈 출력) ❌
```

**해결 방법**:
```bash
# 누락된 DNS Zone VNet Link 수동 추가
az network private-dns link vnet create \
  --name link-openai-jumpbox-krc \
  --resource-group rg-aifoundry-20260128 \
  --zone-name privatelink.openai.azure.com \
  --virtual-network vnet-jumpbox-krc \
  --registration-enabled false
```

---

## 4. 문제 해결 (Troubleshooting)

### 문제 1: ai.azure.com이 열리지 않음

**증상**:
- 브라우저에서 "이 사이트에 연결할 수 없음" (This site can't be reached)
- 또는 무한 로딩

**원인 및 해결책**:

| 원인 | 진단 | 해결 |
|------|------|------|
| **인터넷 연결 차단** | `Test-NetConnection google.com -Port 443` 실패 | NSG 아웃바운드 규칙 확인: `az network nsg rule list --nsg-name nsg-jumpbox-krc --resource-group rg-aifoundry-20260128 --query "[?direction=='Outbound']"` |
| **DNS 해석 실패** | `nslookup ai.azure.com` 오류 | DNS 서버 확인: `Get-DnsClientServerAddress`. Azure VNet DNS(168.63.129.16) 사용해야 함 |
| **Windows 방화벽 차단** | Windows 방화벽 로그 확인 | 방화벽 일시 비활성화 테스트: `Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False` (테스트 후 재활성화 필수!) |
| **브라우저 프록시 설정** | Edge 설정 → 시스템 프록시 확인 | 프록시 비활성화 또는 직접 연결 설정 |

**단계별 해결**:

```powershell
# 1. 인터넷 연결 확인
Test-NetConnection -ComputerName 8.8.8.8 -Port 443
Test-NetConnection -ComputerName ai.azure.com -Port 443

# 2. DNS 캐시 플러시
ipconfig /flushdns
ipconfig /registerdns

# 3. DNS 서버 확인 및 변경 (필요 시)
Get-DnsClientServerAddress -InterfaceAlias Ethernet

# Azure VNet DNS로 변경 (자동으로 설정되어야 하지만, 수동 설정 가능)
# Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses ("168.63.129.16")

# 4. 브라우저 InPrivate 모드 테스트
# Edge InPrivate: Ctrl+Shift+N
# 확장 프로그램 없이 테스트

# 5. tracert로 경로 확인
tracert ai.azure.com
```

### 문제 2: 로그인은 되지만 Hub/Project가 보이지 않음

**증상**:
- https://ai.azure.com 로그인 성공
- "All hubs" 페이지에서 `aihub-foundry` 없음
- 또는 "Access denied" 오류

**원인 및 해결책**:

| 원인 | 진단 | 해결 |
|------|------|------|
| **RBAC 권한 부족** | Azure Portal에서 Hub 리소스 접근 불가 | IAM 역할 확인: 최소 "Contributor" 또는 "Azure ML Workspace Contributor" 필요 |
| **구독 선택 오류** | 다른 구독에 로그인됨 | ai.azure.com 우측 상단 → 설정 → 구독 변경 |
| **Private Endpoint DNS 문제** | Hub API 엔드포인트 연결 실패 | `nslookup aihub-foundry.eastus.api.azureml.ms`로 Private IP 반환 확인 |

**단계별 해결**:

```bash
# Azure CLI로 권한 확인
az role assignment list \
  --assignee <사용자-이메일-또는-ObjectID> \
  --scope /subscriptions/<구독-ID>/resourceGroups/rg-aifoundry-20260128 \
  --query "[].{role:roleDefinitionName, scope:scope}" -o table

# Hub 리소스 직접 접근 테스트
az ml workspace show \
  --name aihub-foundry \
  --resource-group rg-aifoundry-20260128

# Private Endpoint 연결 확인 (Windows PowerShell)
Test-NetConnection -ComputerName aihub-foundry.eastus.api.azureml.ms -Port 443

# DNS 해석 확인 (Private IP여야 함)
nslookup aihub-foundry.eastus.api.azureml.ms
```

### 문제 3: Playground에서 GPT-4o 모델 호출 실패

**증상**:
- Playground에서 "Model deployment not found" 오류
- 또는 "Connection timeout" 오류

**원인 및 해결책**:

| 원인 | 진단 | 해결 |
|------|------|------|
| **OpenAI Private Endpoint DNS 문제** | Azure OpenAI 엔드포인트 해석 실패 | `nslookup aoai-aifoundry.openai.azure.com` 확인 |
| **OpenAI Connection 구성 오류** | Hub에 OpenAI 연결 없음 | Azure Portal → AI Hub → Connections 확인 |
| **Managed Identity 권한 부족** | Hub MI에 OpenAI 역할 없음 | `az role assignment list --assignee <hub-identity-id> --scope <openai-resource-id>` 확인 |

**단계별 해결**:

```powershell
# 1. OpenAI 엔드포인트 연결 테스트 (Windows)
Test-NetConnection -ComputerName aoai-aifoundry.openai.azure.com -Port 443

# 2. DNS 해석 확인 (Private IP 반환되어야 함)
nslookup aoai-aifoundry.openai.azure.com

# 예상: 10.0.1.X (Private Endpoint IP)
```

```bash
# 3. OpenAI 배포 상태 확인 (Azure CLI)
az cognitiveservices account deployment list \
  --name aoai-aifoundry \
  --resource-group rg-aifoundry-20260128 \
  --query "[].{name:name, model:properties.model.name, version:properties.model.version, provisioningState:properties.provisioningState}" -o table

# 예상 출력:
# name                      model                     version      provisioningState
# ------------------------  ------------------------  -----------  -------------------
# gpt-4o                    gpt-4o                    2024-11-20   Succeeded ✅
# text-embedding-ada-002    text-embedding-ada-002    2            Succeeded ✅

# 4. Hub의 OpenAI Connection 확인
az ml connection list \
  --workspace-name aihub-foundry \
  --resource-group rg-aifoundry-20260128 \
  --query "[?type=='azureopenai'].{name:name, target:target, authType:metadata.AuthType}" -o table
```

### 문제 4: "This site can't be reached" 또는 "ERR_NAME_NOT_RESOLVED"

**증상**:
- Private Endpoint를 사용하는 모든 서비스 접근 실패
- DNS 해석 시 Public IP 반환 또는 해석 실패

**원인**: Private DNS Zone이 Korea Central VNet에 연결되지 않음

**해결**:

```bash
# 모든 DNS Zone VNet Link 한번에 확인 (간단 버전)
for zone in api.azureml.ms notebooks.azure.net blob.core.windows.net file.core.windows.net vaultcore.azure.net openai.azure.com cognitiveservices.azure.com search.windows.net azurecr.io azure-api.net; do
    link_count=$(az network private-dns link vnet list \
      --zone-name "privatelink.$zone" \
      --resource-group rg-aifoundry-20260128 \
      --query "length([?contains(virtualNetwork.id, 'vnet-jumpbox-krc')])" -o tsv 2>/dev/null)
    
    if [ "$link_count" == "0" ] || [ -z "$link_count" ]; then
        echo "❌ MISSING: privatelink.$zone → vnet-jumpbox-krc"
    else
        echo "✅ OK: privatelink.$zone → vnet-jumpbox-krc"
    fi
done
```

**누락된 링크 수동 추가 스크립트**:

```bash
#!/bin/bash
# add-missing-dns-links.sh

RG="rg-aifoundry-20260128"
VNET_NAME="vnet-jumpbox-krc"
VNET_ID="/subscriptions/<구독-ID>/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/$VNET_NAME"

DNS_ZONES=(
    "privatelink.api.azureml.ms"
    "privatelink.notebooks.azure.net"
    "privatelink.blob.core.windows.net"
    "privatelink.file.core.windows.net"
    "privatelink.vaultcore.azure.net"
    "privatelink.openai.azure.com"
    "privatelink.cognitiveservices.azure.com"
    "privatelink.search.windows.net"
    "privatelink.azurecr.io"
    "privatelink.azure-api.net"
)

for zone in "${DNS_ZONES[@]}"; do
    link_name="link-${zone//privatelink./}-jumpbox-krc"
    
    echo "Checking $zone..."
    existing=$(az network private-dns link vnet list \
      --zone-name "$zone" \
      --resource-group "$RG" \
      --query "[?contains(virtualNetwork.id, 'vnet-jumpbox-krc')].name" -o tsv 2>/dev/null)
    
    if [ -z "$existing" ]; then
        echo "  Creating link: $link_name"
        az network private-dns link vnet create \
          --name "$link_name" \
          --resource-group "$RG" \
          --zone-name "$zone" \
          --virtual-network "$VNET_ID" \
          --registration-enabled false
    else
        echo "  Link already exists: $existing"
    fi
done

echo "Done!"
```

### 문제 5: 매우 느린 응답 속도

**증상**:
- ai.azure.com 로딩 시간 30초 이상
- Playground 응답 지연

**원인 및 해결책**:

| 원인 | 진단 | 해결 |
|------|------|------|
| **VNet Peering 미연결** | Peering 상태 "Disconnected" | Peering 재생성 또는 재시작 |
| **NSG 규칙 순서 문제** | 낮은 우선순위 Allow 규칙 | NSG 규칙 우선순위 조정 |
| **VM 리소스 부족** | CPU 100%, 메모리 부족 | VM 크기 확대 또는 재시작 |
| **Azure 서비스 장애** | Azure Status 페이지 확인 | https://status.azure.com 모니터링 |

**진단 명령어**:

```powershell
# Windows Jumpbox에서 ping 테스트 (ICMP 허용 시)
Test-NetConnection -ComputerName 10.0.1.1 -InformationLevel Detailed

# tracert로 네트워크 경로 확인
tracert -d 10.0.1.5  # Storage Private Endpoint IP 예시

# VM 리소스 사용률 확인
Get-Counter '\Processor(_Total)\% Processor Time'
Get-Counter '\Memory\Available MBytes'
```

---

## 5. 고급 진단

### 5.1 Network Watcher 패킷 캡처

심각한 네트워크 문제 진단 시 사용:

```bash
# Network Watcher Extension 설치 (Jumpbox VM에)
az vm extension set \
  --resource-group rg-aifoundry-20260128 \
  --vm-name vm-jb-win-krc \
  --name NetworkWatcherAgentWindows \
  --publisher Microsoft.Azure.NetworkWatcher

# 패킷 캡처 시작 (최대 5분)
az network watcher packet-capture create \
  --resource-group rg-aifoundry-20260128 \
  --vm vm-jb-win-krc \
  --name capture-$(date +%Y%m%d-%H%M%S) \
  --storage-account staifoundry20260128 \
  --time-limit 300 \
  --filters "[{\"protocol\":\"TCP\",\"localPort\":\"443\"}]"

# 캡처 중지
az network watcher packet-capture stop \
  --name <capture-name> \
  --location koreacentral

# 캡처 파일 다운로드 후 Wireshark로 분석
```

### 5.2 Azure Monitor Network Insights

```bash
# NSG Flow Logs 활성화
az network watcher flow-log create \
  --location koreacentral \
  --name nsg-flow-log-jumpbox \
  --nsg /subscriptions/<구독-ID>/resourceGroups/rg-aifoundry-20260128/providers/Microsoft.Network/networkSecurityGroups/nsg-jumpbox-krc \
  --storage-account staifoundry20260128 \
  --log-version 2 \
  --retention 7 \
  --workspace /subscriptions/<구독-ID>/resourceGroups/rg-aifoundry-20260128/providers/Microsoft.OperationalInsights/workspaces/log-aifoundry

# Traffic Analytics 활성화 (추가 비용 발생)
az network watcher flow-log update \
  --location koreacentral \
  --name nsg-flow-log-jumpbox \
  --workspace /subscriptions/<구독-ID>/resourceGroups/rg-aifoundry-20260128/providers/Microsoft.OperationalInsights/workspaces/log-aifoundry \
  --interval 10
```

### 5.3 Connection Monitor (종단 간 연결 모니터링)

```bash
# Connection Monitor 생성 (Jumpbox → AI Hub)
az network watcher connection-monitor create \
  --name conn-mon-jumpbox-to-hub \
  --location koreacentral \
  --endpoint-source-name jumpbox \
  --endpoint-source-resource-id /subscriptions/<구독-ID>/resourceGroups/rg-aifoundry-20260128/providers/Microsoft.Compute/virtualMachines/vm-jb-win-krc \
  --endpoint-dest-name aihub \
  --endpoint-dest-address aihub-foundry.eastus.api.azureml.ms \
  --test-config-name tcp-443 \
  --test-config-protocol TCP \
  --test-config-port 443 \
  --test-config-frequency 60 \
  --output-type Workspace \
  --workspace-ids /subscriptions/<구독-ID>/resourceGroups/rg-aifoundry-20260128/providers/Microsoft.OperationalInsights/workspaces/log-aifoundry
```

### 5.4 VM Boot Diagnostics 확인

VM 부팅 문제 또는 네트워크 초기화 문제 진단:

```bash
# Boot Diagnostics 활성화
az vm boot-diagnostics enable \
  --name vm-jb-win-krc \
  --resource-group rg-aifoundry-20260128 \
  --storage https://staifoundry20260128.blob.core.windows.net/

# Serial Console 로그 확인
az vm boot-diagnostics get-boot-log \
  --name vm-jb-win-krc \
  --resource-group rg-aifoundry-20260128
```

---

## 부록 A: 배포된 리소스 목록

### 네트워크 리소스 (Korea Central)

| 리소스 유형 | 이름 | Private IP | Public IP | 설명 |
|-------------|------|------------|-----------|------|
| VNet | `vnet-jumpbox-krc` | 10.1.0.0/16 | - | Korea Central VNet |
| Subnet | `snet-jumpbox` | 10.1.1.0/24 | - | Jumpbox VM 서브넷 |
| Subnet | `AzureBastionSubnet` | 10.1.255.0/26 | - | Bastion 전용 서브넷 |
| Bastion | `bastion-jumpbox-krc` | - | 동적 할당 | Azure Bastion Host |
| NSG | `nsg-jumpbox-krc` | - | - | Jumpbox 서브넷 NSG |
| Windows VM | `vm-jb-win-krc` | 10.1.1.4 | - | Windows 11 Pro |
| Linux VM | `vm-jumpbox-linux-krc` | 10.1.1.5 | - | Ubuntu 22.04 LTS |

### 네트워크 리소스 (East US)

| 리소스 유형 | 이름 | Private IP | Public IP | 설명 |
|-------------|------|------------|-----------|------|
| VNet | `vnet-aifoundry` | 10.0.0.0/16 | - | East US VNet |
| Subnet | `snet-aifoundry` | 10.0.1.0/24 | - | Private Endpoint 서브넷 |
| VNet Peering | `peer-jumpbox-to-main` | - | - | KRC → EUS |
| VNet Peering | `peer-main-to-jumpbox` | - | - | EUS → KRC |

### AI Foundry 리소스 (East US)

| 리소스 유형 | 이름 | Private Endpoint | 설명 |
|-------------|------|------------------|------|
| AI Hub | `aihub-foundry` | `pe-aihub` (10.0.1.X) | AI Foundry Hub |
| AI Project | `aiproj-agents` | Hub PE 공유 | AI Foundry Project |

### AI 서비스 (East US)

| 리소스 유형 | 이름 | Private Endpoint | 배포된 모델 |
|-------------|------|------------------|-------------|
| Azure OpenAI | `aoai-aifoundry` | `pe-openai` (10.0.1.X) | gpt-4o, text-embedding-ada-002 |
| AI Search | `srch-aifoundry-7kkykgt6` | `pe-search` (10.0.1.X) | Standard SKU |

### 스토리지 리소스 (East US)

| 리소스 유형 | 이름 | Private Endpoint | 설명 |
|-------------|------|------------------|------|
| Storage Account | `staifoundry20260128` | `pe-storage-blob` (10.0.1.X)<br/>`pe-storage-file` (10.0.1.X) | Blob, File, Table, Queue |
| Container Registry | `acraifoundryb658f2ug` | `pe-acr` (10.0.1.X) | Premium SKU |

### 보안 리소스 (East US)

| 리소스 유형 | 이름 | Private Endpoint | 설명 |
|-------------|------|------------------|------|
| Key Vault | `kv-aif-e8txcj4l` | `pe-keyvault` (10.0.1.X) | Standard SKU |
| Managed Identity | `id-aifoundry` | - | User-assigned Identity |

### Private DNS Zones (East US)

모든 Private DNS Zone은 `vnet-aifoundry` (East US)와 `vnet-jumpbox-krc` (Korea Central) 모두에 연결되어 있습니다.

1. `privatelink.api.azureml.ms` - AI Foundry API
2. `privatelink.notebooks.azure.net` - AI Foundry Notebooks
3. `privatelink.blob.core.windows.net` - Blob Storage
4. `privatelink.file.core.windows.net` - File Storage
5. `privatelink.vaultcore.azure.net` - Key Vault
6. `privatelink.openai.azure.com` - Azure OpenAI
7. `privatelink.cognitiveservices.azure.com` - Cognitive Services
8. `privatelink.search.windows.net` - AI Search
9. `privatelink.azurecr.io` - Container Registry
10. `privatelink.azure-api.net` - API Management

---

## 부록 B: 빠른 참조 명령어

### Windows Jumpbox (PowerShell)

```powershell
# 네트워크 연결 테스트
Test-NetConnection ai.azure.com -Port 443
Test-NetConnection aihub-foundry.eastus.api.azureml.ms -Port 443

# DNS 해석 확인
nslookup ai.azure.com
nslookup aihub-foundry.eastus.api.azureml.ms

# DNS 캐시 플러시
ipconfig /flushdns
ipconfig /registerdns

# 방화벽 상태 확인
Get-NetFirewallProfile | Select Name, Enabled

# DNS 서버 확인
Get-DnsClientServerAddress -InterfaceAlias Ethernet
```

### Linux Jumpbox (Bash)

```bash
# 네트워크 연결 테스트
curl -I https://ai.azure.com
curl -I https://aihub-foundry.eastus.api.azureml.ms

# DNS 해석 확인
nslookup ai.azure.com
nslookup aihub-foundry.eastus.api.azureml.ms

# traceroute (Private IP로 라우팅 확인)
traceroute -T -p 443 ai.azure.com

# Azure CLI 로그인
az login --use-device-code
az account show
```

### Azure CLI (로컬 또는 Jumpbox)

```bash
# Bastion 연결 (Windows)
az network bastion rdp \
  --name bastion-jumpbox-krc \
  --resource-group rg-aifoundry-20260128 \
  --target-resource-id <vm-id>

# Bastion 연결 (Linux)
az network bastion ssh \
  --name bastion-jumpbox-krc \
  --resource-group rg-aifoundry-20260128 \
  --target-resource-id <vm-id> \
  --auth-type password \
  --username azureuser

# VNet Peering 상태 확인
az network vnet peering list \
  --resource-group rg-aifoundry-20260128 \
  --vnet-name vnet-jumpbox-krc -o table

# NSG 규칙 확인
az network nsg rule list \
  --resource-group rg-aifoundry-20260128 \
  --nsg-name nsg-jumpbox-krc -o table

# Private DNS Zone VNet Link 확인
az network private-dns link vnet list \
  --zone-name privatelink.api.azureml.ms \
  --resource-group rg-aifoundry-20260128 -o table
```

---

## 부록 C: 자주 묻는 질문 (FAQ)

### Q1: Jumpbox에서 ai.azure.com은 열리는데 Hub가 안 보여요.

**A**: RBAC 권한 또는 Private Endpoint DNS 문제일 가능성이 높습니다.
1. Azure Portal에서 Hub 리소스 직접 접근 시도
2. `nslookup aihub-foundry.eastus.api.azureml.ms` 실행 → Private IP(10.0.1.X) 반환되는지 확인
3. 안 되면 Private DNS Zone VNet Link 확인 (위 3.4절 참조)

### Q2: Linux Jumpbox에서 GUI 애플리케이션을 실행할 수 있나요?

**A**: 기본 설치에는 X11 GUI가 없습니다. 필요 시:
```bash
sudo apt update
sudo apt install -y xfce4 xfce4-goodies xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Windows Jumpbox RDP로 Linux Jumpbox GUI 접속 가능
```

### Q3: Jumpbox VM 비용을 절감하려면?

**A**: 
- **사용하지 않을 때 중지**: Azure Portal → VM → "중지" (할당 취소)
- **자동 시작/중지 일정**: Azure Automation 사용
- **작은 VM 크기**: Standard_D4s_v5 → Standard_D2s_v5 변경

### Q4: Private Endpoint IP 주소를 어떻게 확인하나요?

**A**:
```bash
# Storage Blob Private Endpoint IP 확인
az network private-endpoint show \
  --name pe-storage-blob \
  --resource-group rg-aifoundry-20260128 \
  --query "customDnsConfigs[0].ipAddresses[0]" -o tsv

# 또는 DNS 해석으로 확인
nslookup staifoundry20260128.blob.core.windows.net
```

### Q5: VNet Peering 비용은 얼마나 나오나요?

**A**: 
- VNet Peering 자체는 무료
- **데이터 전송 비용**: 리전 간 전송 시 GB당 약 $0.035 (Korea Central ↔ East US)
- 예상: 월 100GB 전송 시 약 $3.50

---

## 지원 및 문의

### Azure Support
- **Azure Portal**: 좌측 메뉴 → "도움말 + 지원" → "새 지원 요청"
- **심각도 수준**:
  - Critical (A): 프로덕션 중단
  - High (B): 업무 영향 큼
  - Medium (C): 중간 영향
  - Low (D): 정보 요청

### 유용한 링크
- [Azure AI Foundry 문서](https://docs.microsoft.com/azure/machine-learning/)
- [Azure Private Link 문서](https://docs.microsoft.com/azure/private-link/)
- [Azure Bastion 문서](https://docs.microsoft.com/azure/bastion/)
- [Azure Network Troubleshooting](https://docs.microsoft.com/azure/network-watcher/)
- [Terraform Azure Provider 문서](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### GitHub Issues
- **리포지토리**: https://github.com/dotnetpower/ai-foundry-private-networking
- **이슈 등록**: 문제 발생 시 GitHub Issue로 보고해 주세요.

---

**문서 버전**: 2.0  
**최종 업데이트**: 2026년 2월 3일  
**작성자**: AI Foundry Private Networking Team
