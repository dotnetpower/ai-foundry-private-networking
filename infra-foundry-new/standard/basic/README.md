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
| **Private DNS Zones** | 6개 | cognitiveservices, openai, services.ai 등 |
| **AI Foundry** | Account, Project, Capability Host | kind=AIServices, networkInjections |
| **모델 배포** | GPT-4o, GPT-5.2, text-embedding-3-large | GlobalStandard SKU |
| **의존 서비스** | Storage, Cosmos DB, AI Search | Private Endpoint 연결 |
| **RAG 인프라** | Storage (rag-documents, rag-chunks), AI Search (semantic), Embedding 모델 | RAG 파이프라인 지원 |
| **Private Endpoints** | 4개 | foundry, storage-blob, cosmos, search |
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

Bicep 배포 시 다음이 자동으로 구성됩니다:
- Account에 `networkInjections`로 Agent 서브넷 주입
- Project 수준 Capability Host 배포 (Storage, Cosmos, Search 연결)
- RBAC 역할 할당

배포 후 VNet 내부에서 (Jumpbox/VPN/ExpressRoute) AI Foundry Portal에 접속하여 Agent를 생성하면 됩니다.

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
