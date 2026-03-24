# Azure AI Foundry Private Networking 배포 가이드

> **참고**: 상세한 Bicep 배포 가이드는 [infra-foundry-new/README.md](../infra-foundry-new/README.md)를 참조하세요.

## 개요

이 문서는 Azure AI Foundry를 프라이빗 네트워킹 환경에서 배포하기 위한 가이드를 제공합니다.

> **AI Foundry New 아키텍처** (2025년 4월~)를 기반으로 작성되었습니다.

---

## 사전 요구사항

### 필수 도구

```bash
# Azure CLI 설치 (최신 버전)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az version

# Bicep 업그레이드
az bicep upgrade
```

### Azure 인증

```bash
# Azure 로그인
az login

# 구독 설정
az account list --output table
az account set --subscription "<구독-ID-또는-이름>"

# 현재 구독 확인
az account show --output table
```

### Azure 권한 확인

필요한 권한:
- **구독 수준**: `Owner` 또는 `Contributor` + `Role Based Access Administrator`
- **RBAC 할당**: `Microsoft.Authorization/roleAssignments/write`

---

## 배포되는 리소스

| 카테고리 | 리소스 | 필수/선택 |
|----------|--------|-----------|
| **네트워킹** | Virtual Network | 필수 |
| | Subnets (Agent, PE, Jumpbox, Bastion) | 필수 |
| | Network Security Groups | 필수 |
| | Private DNS Zones (7개) | 필수 |
| **AI Foundry** | AI Foundry Account (AIServices) | 필수 |
| | AI Foundry Project | 필수 |
| | GPT-5.4, text-embedding-ada-002 | 필수 |
| **의존 서비스** | Storage Account | 필수 |
| | Cosmos DB | 필수 |
| | Azure AI Search | 필수 |
| **네트워크 격리** | Private Endpoints (5개) | 필수 |
| | Connections (3개) | 필수 |
| **Jumpbox** | Linux VM | **선택** |
| | Windows VM | **선택** |
| | Azure Bastion | **선택** |

---

## 배포 절차

### 1단계: 파라미터 파일 설정

```bash
cd infra-foundry-new
cp parameters/dev.bicepparam parameters/my-env.bicepparam
```

파라미터 파일 수정:
```bicep
using '../main.bicep'

param location = 'swedencentral'
param resourceGroupName = 'rg-aifoundry-bicep'
param environmentName = 'dev'

// 네트워크 설정
param vnetAddressPrefix = '192.168.0.0/16'
param agentSubnetAddressPrefix = '192.168.0.0/24'
param privateEndpointSubnetAddressPrefix = '192.168.1.0/24'

// Jumpbox 배포 여부
param deployJumpbox = false
param jumpboxAdminUsername = 'azureuser'
param jumpboxAdminPassword = '<안전한-비밀번호>'
```

### 2단계: 리소스 프로바이더 등록

```bash
az provider register --namespace 'Microsoft.CognitiveServices'
az provider register --namespace 'Microsoft.Storage'
az provider register --namespace 'Microsoft.Search'
az provider register --namespace 'Microsoft.Network'
az provider register --namespace 'Microsoft.App'
az provider register --namespace 'Microsoft.DocumentDB'
```

### 3단계: Bicep 배포

```bash
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/my-env.bicepparam \
  --name my-deployment
```

예상 배포 시간: **약 15-20분**

### 4단계: Capability Host 설정 (수동)

Bicep 배포 후 Azure Portal에서 Standard Agent Setup을 구성해야 합니다:

1. **Azure Portal** > **AI Foundry** > 배포된 Project 선택
2. **Management** > **Agent setup** 클릭
3. **Standard agent setup** 선택
4. 설정:
   - **Virtual Network**: 배포된 VNet 선택
   - **Subnet**: Agent 서브넷 선택
   - **Storage Connection**: storage-connection
   - **AI Search Connection**: search-connection
   - **Cosmos DB Connection**: cosmos-connection
5. **Apply** 클릭

---

## 배포 검증

### 리소스 확인

```bash
# 리소스 그룹 확인
az resource list --resource-group <rg-name> -o table

# Foundry Account 확인
az cognitiveservices account show \
  --name <foundry-account-name> \
  --resource-group <rg-name>

# Private Endpoint 상태 확인
az network private-endpoint list \
  --resource-group <rg-name> \
  --query "[].{name:name, status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
  -o table
```

### DNS 해석 확인 (VNet 내부에서)

```bash
nslookup <foundry-account-name>.cognitiveservices.azure.com
nslookup <storage-account-name>.blob.core.windows.net
nslookup <cosmos-account-name>.documents.azure.com
nslookup <search-service-name>.search.windows.net
```

기대 결과: `192.168.x.x` 대역의 프라이빗 IP

---

## 삭제

```bash
# 1. 리소스 그룹 삭제
az group delete --name <rg-name> --yes

# 2. Cognitive Services Purge (필수)
az cognitiveservices account purge \
  --name <foundry-account-name> \
  --resource-group <rg-name> \
  --location swedencentral
```

> **중요**: Purge 없이 재배포 시 "Subnet already in use" 오류 발생

---

## 트러블슈팅

| 오류 메시지 | 해결 방법 |
|------------|----------|
| `Korea Central SKU 오류` | Sweden Central 리전 사용, GlobalStandard SKU |
| `Subnet already in use` | 이전 Foundry 리소스 Purge 필요 |
| `virtualNetworkSubnetResourceId not found` | Capability Host는 Azure Portal에서 수동 설정 |
| `Connection category 오류` | `AzureStorageAccount` 카테고리 사용 |

---

## 참고 자료

- [Bicep 배포 상세 가이드](../infra-foundry-new/README.md)
- [Microsoft Learn - Set up private networking](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
