# Bicep 배포 가이드

Azure Foundry Agent Service를 프라이빗 네트워크 환경에서 배포하기 위한 Bicep 템플릿입니다.

> **⚠️ AI Foundry New 버전 기준**
>
> 이 템플릿은 **AI Foundry New 아키텍처** (2025년 4월~)를 기반으로 작성되었습니다.
> - **리소스 타입**: `Microsoft.CognitiveServices/accounts` (kind=AIServices)
> - **프로젝트**: `accounts/projects` 하위 리소스
> - **API 버전**: `2025-04-01-preview`
> - **Agent Setup**: Standard Agent Setup (Capability Host)

## 개요

이 템플릿은 [Microsoft Learn - Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks) 문서를 기반으로 작성되었습니다.

### 배포 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Virtual Network (192.168.0.0/16)                     │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Agent Subnet (192.168.0.0/24)                                        │ │
│  │  - Microsoft.App/environments 위임                                    │ │
│  │  - Foundry Agent 런타임 호스팅                                         │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Private Endpoint Subnet (192.168.1.0/24)                             │ │
│  │  - pe-foundry (Foundry Account)                                       │ │
│  │  - pe-storage (Azure Storage)                                         │ │
│  │  - pe-cosmos (Azure Cosmos DB)                                        │ │
│  │  - pe-search (Azure AI Search)                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Jumpbox Subnet (192.168.2.0/24) [선택]                               │ │
│  │  - vm-jumpbox-win (Windows 11 Pro)                                     │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  AzureBastionSubnet (192.168.255.0/26) [선택]                         │ │
│  │  - bastion-host                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 사전 요구사항

### 필수 조건

- Azure 구독
- Azure CLI 최신 버전
- 다음 역할 중 하나:
  - **Owner** (구독 수준) - 권장
  - **Role Based Access Administrator** + **Contributor**
- 필수 권한: `Microsoft.Authorization/roleAssignments/write`

### 리소스 프로바이더 등록

```bash
az provider register --namespace 'Microsoft.KeyVault'
az provider register --namespace 'Microsoft.CognitiveServices'
az provider register --namespace 'Microsoft.Storage'
az provider register --namespace 'Microsoft.MachineLearningServices'
az provider register --namespace 'Microsoft.Search'
az provider register --namespace 'Microsoft.Network'
az provider register --namespace 'Microsoft.App'
az provider register --namespace 'Microsoft.ContainerService'
az provider register --namespace 'Microsoft.DocumentDB'

# Bing Search 도구 사용 시 (선택)
az provider register --namespace 'Microsoft.Bing'
```

### 등록 상태 확인

```bash
az provider show --namespace 'Microsoft.App' --query "registrationState" -o tsv
```

## 배포

### 1. 파라미터 파일 수정

`parameters/dev.bicepparam` 파일을 환경에 맞게 수정합니다:

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
param deployJumpbox = true
param jumpboxAdminUsername = 'azureuser'
param jumpboxAdminPassword = '<안전한-비밀번호>'
```

### 2. 배포 실행

```bash
# Azure 로그인
az login
az account set --subscription "<구독-ID>"

# Bicep 배포
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

### 3. 배포 확인

```bash
# 리소스 그룹 확인
az group show --name rg-aifoundry-bicep

# Foundry 리소스 확인
az cognitiveservices account show \
  --name cog-foundry-dev \
  --resource-group rg-aifoundry-bicep

# Private Endpoint 상태 확인
az network private-endpoint list \
  --resource-group rg-aifoundry-bicep \
  --query "[].{name:name, status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
  -o table
```

## 배포 검증

### 1. 서브넷 위임 확인

Azure Portal > VNet > Subnets에서 Agent 서브넷의 위임이 `Microsoft.App/environments`로 설정되어 있는지 확인합니다.

### 2. 공용 네트워크 접근 비활성화 확인

각 리소스(Foundry, AI Search, Storage, Cosmos DB)의 **Public network access**가 **Disabled**로 설정되어 있는지 확인합니다.

### 3. Private DNS 해석 확인

VNet에 연결된 머신에서 각 엔드포인트에 대해 `nslookup`을 실행하여 프라이빗 IP로 해석되는지 확인합니다:

```bash
nslookup <foundry-account-name>.cognitiveservices.azure.com
nslookup <storage-account-name>.blob.core.windows.net
nslookup <cosmos-account-name>.documents.azure.com
nslookup <search-service-name>.search.windows.net
```

기대 결과: `10.x.x.x`, `172.16-31.x.x`, 또는 `192.168.x.x` 대역의 프라이빗 IP

### 4. Agent 연결 테스트

VNet 내부에서 Foundry 프로젝트에 접근하여 Agent를 생성하고 실행할 수 있는지 확인합니다.

## 모듈 구조

```
infra-bicep/
├── main.bicep                      # 메인 배포 템플릿 (구독 수준)
├── parameters/
│   └── dev.bicepparam              # 개발 환경 파라미터
└── modules/
    ├── networking/
    │   └── main.bicep              # VNet, Subnet, NSG, Private DNS Zones
    ├── ai-foundry/
    │   └── main.bicep              # Foundry Account, Project, 모델 배포
    ├── dependent-resources/
    │   └── main.bicep              # Storage, Cosmos DB, AI Search
    ├── private-endpoints/
    │   └── main.bicep              # Private Endpoints, DNS Zone Groups
    └── jumpbox/
        └── main.bicep              # Jumpbox VM, Bastion (선택)
```

## 알려진 제한 사항

| 제한 사항 | 설명 |
|----------|------|
| **서브넷 IP 범위** | RFC1918 프라이빗 IP만 지원 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) |
| **Agent 서브넷 독점성** | Foundry 리소스별 전용 Agent 서브넷 필요 |
| **서브넷 크기** | Agent 서브넷 최소 /27 (32개 IP), 권장 /24 (256개 IP) |
| **리전 일관성** | 모든 리소스는 VNet과 동일 리전에 배포 필수 |
| **Blob Storage** | File Search 도구에서 Azure Blob Storage 파일 미지원 |

## 삭제

리소스 삭제 시 다음 순서를 준수하세요:

1. Foundry 리소스 삭제
2. Foundry 리소스 **Purge** (삭제된 리소스 완전 제거)
3. Virtual Network 삭제

```bash
# 1. 리소스 그룹 내 리소스 삭제
az group delete --name rg-aifoundry-bicep --yes

# 2. 삭제된 Cognitive Services 리소스 Purge
az cognitiveservices account purge \
  --name cog-foundry-dev \
  --resource-group rg-aifoundry-bicep \
  --location swedencentral
```

> **중요**: Purge 없이 VNet을 삭제하면 "Subnet already in use" 오류가 발생할 수 있습니다.

## 문제 해결

### Template deployment errors

| 오류 메시지 | 해결 방법 |
|------------|----------|
| `CreateCapabilityHostRequestDto is invalid` | 모든 BYO 리소스(Storage, Cosmos DB, AI Search) 연결 필요 |
| `Provided subnet must be of the proper address space` | RFC1918 범위의 프라이빗 IP 사용 확인 |
| `Subscription is not registered with required resource providers` | `az provider register` 명령으로 등록 |
| `Capability host operation failed` | Support ticket 생성, Capability Host 오류 확인 |
| `Timeout of 60000ms exceeded` | Cosmos DB 연결 확인, 방화벽 규칙 점검 |

### Private DNS 해석 실패

1. Private DNS Zone이 VNet에 연결되어 있는지 확인
2. 조건부 포워더가 Azure DNS (168.63.129.16)를 가리키는지 확인
3. VNet 내부 머신에서 `nslookup`으로 테스트

## 배포 상태 (2026-03-17 검증)

### ✅ 정상 배포되는 리소스

| 카테고리 | 리소스 | 비고 |
|----------|--------|------|
| **네트워크** | VNet, Subnets, NSGs | 192.168.0.0/16 |
| **Private DNS Zones** | 7개 전체 | cognitiveservices, openai, services.ai, search, documents, blob, file |
| **AI Foundry** | Account (AIServices kind) | `cog-{suffix}` |
| **AI Foundry** | Project | `proj-{suffix}` |
| **모델 배포** | GPT-5.4, text-embedding-ada-002 | GlobalStandard SKU |
| **의존 서비스** | Storage Account | Blob 컨테이너 포함 |
| **의존 서비스** | Cosmos DB | Database + Container 포함 |
| **의존 서비스** | AI Search | Basic SKU |
| **Private Endpoints** | 5개 | foundry, storage-blob, storage-file, cosmos, search |
| **Connections** | 3개 | storage, cosmos, search (AAD 인증) |
| **RBAC** | 9개 역할 할당 | Storage, Cosmos, Search 역할 |
| **Managed Identity** | User-assigned | Foundry Account 연결 |

### ⚠️ 수동 설정 필요한 리소스

| 리소스 | 상태 | 원인 |
|--------|------|------|
| **Capability Host** | 수동 설정 필요 | `virtualNetworkSubnetResourceId` 속성이 현재 Bicep API에서 미지원 |
| **Jumpbox VMs** | 선택적 배포 | `deployJumpbox = true` 설정 시 배포 |

### ❌ 제한 사항

| 항목 | 상태 |
|------|------|
| Korea Central 리전 | GPT-5.4 GlobalStandard SKU 미지원, Sweden Central 권장 |
| Capability Host IaC | Bicep/Terraform 자동화 불가 (2025-04-01-preview API 기준) |

---

## Capability Host 수동 설정 가이드

Bicep 배포 완료 후 **Standard Agent Setup**을 위한 Capability Host는 Azure Portal에서 수동으로 설정해야 합니다.

### 방법 1: Azure Portal (권장)

1. **Azure Portal** > **AI Foundry** > 배포된 Project 선택
2. 좌측 메뉴에서 **Management** > **Agent setup** 클릭
3. **Standard agent setup** 선택
4. 다음 항목 설정:
   - **Virtual Network**: 배포된 VNet 선택 (`vnet-aifoundry-dev`)
   - **Subnet**: Agent 서브넷 선택 (192.168.0.0/24, `Microsoft.App/environments` 위임됨)
   - **Storage Connection**: `storage-connection` 선택
   - **AI Search Connection**: `search-connection` 선택
   - **Cosmos DB Connection**: `cosmos-connection` 선택
5. **Apply** 클릭 후 5-10분 대기

### 방법 2: Azure CLI

```bash
# 변수 설정
RESOURCE_GROUP="rg-aif-swc5"
FOUNDRY_ACCOUNT="cog-jinec4x3"
PROJECT_NAME="proj-jinec4x3"
AGENT_SUBNET_ID="/subscriptions/<subscription-id>/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/vnet-aifoundry-dev/subnets/snet-agent"

# REST API로 Capability Host 생성
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY_ACCOUNT}/projects/${PROJECT_NAME}/capabilityHosts/default?api-version=2025-04-01-preview" \
  --body '{
    "properties": {
      "capabilityHostKind": "Agents",
      "virtualNetworkSubnetResourceId": "'${AGENT_SUBNET_ID}'",
      "storageConnections": ["storage-connection"],
      "vectorStoreConnections": ["search-connection"]
    }
  }'
```

### 방법 3: Python SDK

```python
from azure.identity import DefaultAzureCredential
from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient

credential = DefaultAzureCredential()
client = CognitiveServicesManagementClient(
    credential, 
    subscription_id="<subscription-id>"
)

# Capability Host 생성
capability_host = client.capability_hosts.begin_create_or_update(
    resource_group_name="rg-aif-swc5",
    account_name="cog-jinec4x3",
    project_name="proj-jinec4x3",
    capability_host_name="default",
    capability_host={
        "properties": {
            "capabilityHostKind": "Agents",
            "virtualNetworkSubnetResourceId": "<agent-subnet-id>",
            "storageConnections": ["storage-connection"],
            "vectorStoreConnections": ["search-connection"]
        }
    }
).result()
```

### Capability Host 설정 확인

```bash
# Capability Host 상태 확인
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY_ACCOUNT}/projects/${PROJECT_NAME}/capabilityHosts/default?api-version=2025-04-01-preview"
```

### 트러블슈팅

| 오류 | 원인 | 해결 |
|------|------|------|
| `Subnet already in use` | 이전 배포의 Foundry 리소스가 Purge되지 않음 | `az cognitiveservices account purge` 실행 |
| `CreateCapabilityHostRequestDto is invalid` | Connection 설정 누락 | Storage, Cosmos, Search Connection 확인 |
| `CapabilityHostOperationFailed` | RBAC 미할당 | Managed Identity에 필요한 역할 확인 |
| `Subnet delegation missing` | 서브넷 위임 미설정 | Agent 서브넷에 `Microsoft.App/environments` 위임 확인 |

---

## 참고 자료

- [Microsoft Learn - Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
- [GitHub - Foundry Samples (Bicep)](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup)
- [Azure Container Apps - Subnet sizing](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks#subnet)
