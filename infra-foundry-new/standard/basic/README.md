# Standard Agent Setup (Private Networking)

Standard Agent Setup은 **프라이빗 네트워크** 환경에서 Foundry Agent Service를 운영합니다.

## 개요

VNet + Private Endpoint 기반으로 모든 트래픽이 Microsoft 백본 네트워크를 통해 전달됩니다.
**Hub-Spoke 토폴로지**를 지원하여 기존 Hub VNet과 연결할 수 있습니다.

### 배포되는 리소스

| 카테고리 | 리소스 | 비고 |
|----------|--------|------|
| **네트워크** | VNet, Subnets (3개), NSGs | 192.168.0.0/16 |
| **Hub-Spoke** | VNet Peering (양방향), DNS Zone Hub Link | 선택적 |
| **Private DNS Zones** | 7개 | cognitiveservices, openai, services.ai 등 |
| **AI Foundry** | Account, Project | kind=AIServices |
| **모델 배포** | GPT-4o, GPT-5.2, text-embedding-3-large | GlobalStandard SKU |
| **의존 서비스** | Storage, Cosmos DB, AI Search | Private Endpoint 연결 |
| **RAG 인프라** | Storage (rag-documents, rag-chunks), AI Search (semantic), Embedding 모델 | RAG 파이프라인 지원 |
| **Private Endpoints** | 5개 | foundry, storage-blob, storage-file, cosmos, search |
| **RBAC** | 9개 역할 할당 | Managed Identity 기반 |
| **Jumpbox** (선택) | Windows VM + Public IP | VNet 내부 접속용 (RDP) |

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                 Hub VNet (10.0.0.0/16) [선택]                  │
│     ※ setup-hub-spoke.sh로 사전 생성                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  GatewaySubnet / SharedSubnet                           │   │
│  └─────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ VNet Peering (양방향)
┌──────────────────────────┴──────────────────────────────────────┐
│            Spoke VNet (192.168.0.0/16)                          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Agent Subnet (192.168.0.0/24)                          │   │
│  │  - Microsoft.App/environments 위임                      │   │
│  │  - Standard Agent Service (Portal에서 프로비저닝)         │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Private Endpoint Subnet (192.168.1.0/24)               │   │
│  │  - Foundry, Storage (blob/file), Cosmos DB, AI Search   │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Jumpbox Subnet (192.168.2.0/24) [선택]                 │   │
│  │  - Windows VM + Public IP (RDP)                         │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

RAG 데이터 흐름:
  Storage(rag-documents) → AI Search(semantic+vector) → GPT-5.2
  (text-embedding-3-large로 벡터 임베딩)
```

## 배포

### 1단계: Bicep 인프라 배포

**Standalone VNet (Hub-Spoke 없이):**
```bash
cd infra-foundry-new/standard/basic

az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

**Hub-Spoke 구성:**
```bash
# 0. Hub VNet 사전 생성
./scripts/setup-hub-spoke.sh --location swedencentral --env dev

# 1. Hub VNet ID 조회
HUB_VNET_ID=$(az network vnet show \
  -g rg-aif-hub-swc-dev -n vnet-hub-dev --query id -o tsv)

# 2. Hub-Spoke 포함 배포
cd infra-foundry-new/standard/basic
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters hubVnetId="${HUB_VNET_ID}" \
               hubVnetResourceGroup='rg-aif-hub-swc-dev' \
               hubVnetName='vnet-hub-dev'
```

배포 시간: 약 15-20분

### 2단계: Portal에서 Agent Setup 구성

Bicep 배포가 완료되면 Azure AI Foundry Portal에서 Agent를 설정합니다.

> **왜 Portal 설정이 필요한가?**
> Agent의 VNet 연동 설정은 Bicep API에서 미지원이므로,
> Bicep으로 인프라(VNet, PE, DNS, RBAC)를 배포한 후 Agent 연결은 Portal에서 수동 구성합니다.

#### Step 1: AI Foundry Portal 접속

1. [Azure AI Foundry Portal](https://ai.azure.com) 접속
2. 좌측 메뉴에서 **모든 프로젝트** 클릭
3. Bicep으로 배포된 Project (`proj-xxxxxxxx`) 선택

#### Step 2: Agent Setup 진입

1. 좌측 메뉴 **관리(Management)** > **에이전트(Agents)** 클릭
2. **에이전트 설정(Agent setup)** 버튼 클릭
3. **Standard agent setup** 선택 (Private Networking 지원)

#### Step 3: 네트워크 구성

1. **Virtual Network** 드롭다운에서 Bicep으로 생성된 VNet 선택
   - 예: `vnet-aifoundry-dev`
2. **Subnet** 드롭다운에서 Agent 서브넷 선택
   - 예: `snet-agent` (192.168.0.0/24, `Microsoft.App/environments` 위임됨)

#### Step 4: Connection 구성

| Connection 항목 | 선택할 Connection | 용도 |
|-----------------|-------------------|------|
| **AI Services** | (자동 연결) | Foundry Account 기본 연결 |
| **Storage** | `storage-connection` | Agent 데이터 저장 (agents-data 컨테이너) |
| **Thread Storage** | `cosmos-connection` | 대화 스레드 저장 (Cosmos DB agentdb) |
| **Vector Store** | `search-connection` | RAG 벡터 검색 (AI Search semantic) |

#### Step 5: 적용 및 프로비저닝

1. **적용(Apply)** 클릭
2. 프로비저닝 진행 (약 5-10분 소요)
   - Managed Environment 생성
   - Container App 배포
   - Private Endpoint 자동 생성
3. 상태가 **Succeeded**로 변경되면 완료

#### Step 6: 동작 확인

1. 좌측 메뉴 **에이전트(Agents)** 클릭
2. **+ 새 에이전트(New Agent)** 클릭
3. 모델 선택: `gpt-4o` 또는 `gpt-5.2`
4. 시스템 프롬프트 입력 후 테스트 메시지 전송
5. 응답이 정상적으로 반환되면 Agent Setup 완료

> **RAG 활용 시**: Agent 생성 후 **도구(Tools)** > **파일 검색(File Search)** 추가 →
> Vector Store 생성 → `rag-documents` 컨테이너의 파일 업로드 →
> `text-embedding-3-large` 모델로 자동 임베딩

## 배포 검증

```bash
./scripts/verify-deployment.sh rg-aif-new-swc-dev
```

## Jumpbox 옵션

VNet 내부 리소스에 접근하려면 Jumpbox가 필요합니다.

```bash
# Jumpbox 포함 배포
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters deployJumpbox=true
```

## 삭제

```bash
# 1. 리소스 그룹 삭제
az group delete --name rg-aif-new-swc-dev --yes

# 2. Cognitive Services Purge (필수 - 안 하면 재배포 시 subnet 충돌)
az cognitiveservices account purge \
  --name <account-name> \
  --resource-group rg-aif-new-swc-dev \
  --location swedencentral
```
