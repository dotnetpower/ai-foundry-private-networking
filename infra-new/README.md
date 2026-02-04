# AI Foundry Standard Agent Setup (Private Network)

이 폴더는 Microsoft 공식 문서 [15-private-network-standard-agent-setup](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup/README.md)을 기반으로 한 Terraform 구현입니다.

## 빠른 시작

### Linux/macOS (Bash)

```bash
# 1. 설정 파일 생성
cp config.env.example config.env
# config.env를 편집하여 구독 ID 등 설정

# 2. 전체 배포 실행
./deploy.sh
```

### Windows (PowerShell)

```powershell
# 1. 설정 파일 생성
Copy-Item config.env.example config.env
# config.env를 편집하여 구독 ID 등 설정

# 2. 전체 배포 실행
.\deploy.ps1

# 가용성 검사 건너뛰기 (선택적)
.\deploy.ps1 -SkipAvailabilityCheck
```

### 스크립트 기능

| 기능 | 설명 |
|------|------|
| **리소스 가용성 사전 검사** | AI Search SKU, OpenAI, CapabilityHost 리전 지원 여부 확인 |
| **VNet 자동 생성** | 기존 VNet이 없으면 자동 생성 |
| **재시도 로직** | Provider 버그, 네트워크 오류 등에 대한 자동 재시도 |
| **인터랙티브 오류 처리** | SKU 변경, 리전 변경 등 인터랙티브 선택 지원 |

## 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           VNet (10.0.0.0/16)                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  agent-subnet (10.0.0.0/24) - Microsoft.App/environments 위임       │   │
│  │  - Capability Host의 Agent 워크로드 실행                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  pe-subnet (10.0.1.0/24) - Private Endpoints                        │   │
│  │  - AI Services, Storage, CosmosDB, Search Private Endpoints         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 배포 단계

| 단계 | 스크립트 | 설명 | 예상 시간 |
|------|----------|------|-----------|
| 1 | `01-prerequisites.sh` | 사전 요구사항 확인, Resource Provider 등록 | 2분 |
| 2 | `02-setup-vnet.sh` | VNet/서브넷 구성 (기존 사용 또는 신규 생성) | 3분 |
| 3 | `03-deploy-ai-foundry.sh` | Terraform으로 AI Foundry 배포 | 20-30분 |
| 4 | `04-upload-test-data.sh` | 테스트 문서 Blob Storage 업로드 | 2분 |
| 5 | `05-setup-ai-search.sh` | AI Search 인덱스/인덱서 설정 | 5분 |
| 6 | `06-validate-deployment.sh` | 배포 검증 및 결과 출력 | 2분 |

**총 예상 시간: 약 35-45분**

## 주요 리소스

| 리소스 | 유형 | 설명 |
|--------|------|------|
| AI Services Account | `Microsoft.CognitiveServices/accounts` | AI Foundry 계정 (kind=AIServices) |
| AI Project | `Microsoft.CognitiveServices/accounts/projects` | Agent 개발용 프로젝트 |
| Capability Host | `Microsoft.CognitiveServices/accounts/projects/capabilityHosts` | Agent 실행 환경 |
| CosmosDB | `Microsoft.DocumentDB/databaseAccounts` | Thread Storage (대화 이력) |
| Storage Account | `Microsoft.Storage/storageAccounts` | File Storage (파일 업로드) |
| AI Search | `Microsoft.Search/searchServices` | Vector Store (RAG 패턴) |

## 배포 순서 (필수!)

1. **네트워킹**: VNet, Subnets (Agent 서브넷에 `Microsoft.App/environments` 위임)
2. **의존 리소스**: Storage, CosmosDB, AI Search (Private Endpoint 포함)
3. **AI Services Account**: Cognitive Services 계정 (networkInjections 설정)
4. **Private Endpoints**: 모든 서비스에 Private Endpoint 연결
5. **AI Project**: Account 하위에 Project 생성 + Connections 설정
6. **RBAC 역할 할당**: Storage, CosmosDB, Search에 Project SMI 권한 부여
7. **Capability Host**: Project에 capabilityHost 생성

## 사전 요구사항

```bash
# Resource Provider 등록
az provider register --namespace 'Microsoft.CognitiveServices'
az provider register --namespace 'Microsoft.Storage'
az provider register --namespace 'Microsoft.Search'
az provider register --namespace 'Microsoft.DocumentDB'
az provider register --namespace 'Microsoft.Network'
az provider register --namespace 'Microsoft.App'
az provider register --namespace 'Microsoft.ContainerService'
```

## 배포 방법

```bash
cd infra-new
./deploy.sh
```

## 삭제 시 주의사항

**중요**: Capability Host가 있는 Account를 삭제할 때는 반드시 **Purge**까지 완료해야 합니다.

```bash
# 1. Project Capability Host 삭제
./scripts/delete-caphost.sh project

# 2. Account 삭제
terraform destroy

# 3. Account Purge (완전 삭제)
az cognitiveservices account purge --name <account-name> --resource-group <rg-name> --location <location>
```

## 문제 해결

### CapabilityHostOperationFailed

**원인**: RBAC 역할이 제대로 할당되지 않았거나, Private Endpoint 연결이 완료되지 않음

**해결 방법**:
1. Project SMI에 다음 역할이 할당되었는지 확인:
   - Storage: `Storage Blob Data Contributor`, `Storage Blob Data Owner`
   - CosmosDB: `Cosmos DB Operator`, `Cosmos DB Built-in Data Contributor`
   - AI Search: `Search Index Data Contributor`, `Search Service Contributor`
2. Private Endpoint가 `Succeeded` 상태인지 확인
3. DNS Zone이 올바르게 VNet에 연결되었는지 확인

### Subnet already in use

**원인**: 이전 배포의 Capability Host가 완전히 삭제되지 않음

**해결 방법**:
```bash
# Account Purge 후 20분 대기
az cognitiveservices account purge --name <account-name> --resource-group <rg-name> --location <location>
```

---

## 리전별 리소스 가용성 테스트 결과

> **테스트 일시**: 2026년 2월 5일 (수요일) 오전 11:30 KST

### Sweden Central (swedencentral) - ✅ 권장

| 리소스 | 상태 | 세부 정보 |
|--------|------|-----------|
| **리전** | ✅ 사용 가능 | Sweden Central 존재 확인 |
| **AI Services** | ✅ S0 SKU | Standard 티어 |
| **OpenAI** | ✅ S0 SKU | Standard 티어 (전 모델 지원) |
| **AI Search (free)** | ✅ 가용 | 한도: 1, 사용: 0 |
| **AI Search (basic)** | ✅ 가용 | 한도: 12, 사용: 0 |
| **AI Search (standard)** | ✅ 가용 | 한도: 12, 사용: 0 |
| **AI Search (standard2)** | ❌ 불가 | 한도: 0 |
| **AI Search (standard3)** | ❌ 불가 | 한도: 0 |
| **CapabilityHost** | ✅ 지원 | Standard Agent Setup 지원 리전 |

### East US (eastus) - ✅ 권장

| 리소스 | 상태 | 세부 정보 |
|--------|------|-----------|
| **리전** | ✅ 사용 가능 | East US 존재 확인 |
| **AI Services** | ✅ S0 SKU | Standard 티어 |
| **OpenAI** | ✅ S0 SKU | Standard 티어 (주요 모델 지원) |
| **AI Search (free)** | ✅ 가용 | 한도: 1, 사용: 0 |
| **AI Search (basic)** | ✅ 가용 | 한도: 12, 사용: 0 |
| **AI Search (standard)** | ✅ 가용 | 한도: 12, 사용: 0 |
| **AI Search (standard2)** | ❌ 불가 | 한도: 0 |
| **AI Search (standard3)** | ❌ 불가 | 한도: 0 |
| **AI Search (enhanced_density)** | ✅ 가용 | 한도: 12 (1/4/8 모두) |
| **CapabilityHost** | ✅ 지원 | Standard Agent Setup 지원 리전 |

### East US 2 (eastus2) - ✅ 권장 (전 모델 지원)

| 리소스 | 상태 | 세부 정보 |
|--------|------|-----------|
| **리전** | ✅ 사용 가능 | East US 2 존재 확인 |
| **AI Services** | ✅ S0 SKU | Standard 티어 |
| **OpenAI** | ✅ S0 SKU | Standard 티어 (GPT-5.x, o-series 전 모델 지원) |
| **AI Search (free)** | ✅ 가용 | 한도: 1, 사용: 0 |
| **AI Search (basic)** | ✅ 가용 | 한도: 12, 사용: 0 |
| **AI Search (standard)** | ✅ 가용 | 한도: 12, 사용: 0 |
| **AI Search (standard2)** | ❌ 불가 | 한도: 0 |
| **AI Search (standard3)** | ❌ 불가 | 한도: 0 |
| **AI Search (enhanced_density)** | ✅ 가용 | 한도: 12 (1/4/8 모두) |
| **CapabilityHost** | ✅ 지원 | Standard Agent Setup 지원 리전 |

### 리소스 공급자 등록 상태

| 공급자 | 상태 |
|--------|------|
| Microsoft.App | ✅ Registered |
| Microsoft.CognitiveServices | ✅ Registered |
| Microsoft.Search | ✅ Registered |
| Microsoft.Storage | ✅ Registered |
| Microsoft.DocumentDB (CosmosDB) | ✅ Registered |
| Microsoft.MachineLearningServices | ✅ Registered |

### CapabilityHost 지원 리전 (2026년 2월 기준)

```
westus, eastus, eastus2, japaneast, francecentral, spaincentral,
uaenorth, southcentralus, italynorth, germanywestcentral, brazilsouth,
southafricanorth, australiaeast, swedencentral, canadaeast,
westeurope, westus3, uksouth, southindia, koreacentral,
polandcentral, switzerlandnorth, norwayeast
```

### 리전 선택 가이드

| 리전 | 모든 모델 지원 | AI Search 가용성 | 권장도 |
|------|---------------|------------------|--------|
| **swedencentral** | ✅ 전체 (GPT-5.x, o-series 등) | ✅ basic, standard | ⭐⭐⭐ |
| **eastus2** | ✅ 전체 (GPT-5.x, o-series 등) | ✅ basic, standard, enhanced_density | ⭐⭐⭐ |
| **eastus** | ⚠️ 부분 (GPT-4o, o3-mini) | ✅ basic, standard, enhanced_density | ⭐⭐⭐ |
| **westeurope** | ⚠️ 부분 | 확인 필요 | ⭐⭐ |
| **koreacentral** | ⚠️ 부분 | 확인 필요 | ⭐⭐ |

> **참고**: 모든 테스트 리전에서 `standard2`, `standard3`, `storage_optimized` SKU는 사용 불가 (한도: 0)

### 가용성 확인 명령어

```bash
# AI Search 할당량 확인 (REST API)
SUB_ID=$(az account show --query id -o tsv)
TOKEN=$(az account get-access-token --query accessToken -o tsv)
curl -s -X GET \
  "https://management.azure.com/subscriptions/${SUB_ID}/providers/Microsoft.Search/locations/swedencentral/usages?api-version=2024-03-01-preview" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.value[] | {name: .name.value, limit: .limit, currentValue: .currentValue}'

# Cognitive Services SKU 확인
az cognitiveservices account list-skus --kind AIServices --location swedencentral -o table

# 리소스 공급자 상태 확인
az provider show -n Microsoft.App --query registrationState -o tsv
az provider show -n Microsoft.CognitiveServices --query registrationState -o tsv
az provider show -n Microsoft.Search --query registrationState -o tsv
```
