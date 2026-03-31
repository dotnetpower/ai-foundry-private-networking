# Standard Agent Setup (Managed VNet — Preview)

⚠️ **Preview 기능** — 프로덕션 환경에서는 [basic/](../basic/) (BYO VNet) 방식을 사용하세요.

## 개요

Azure가 Agent용 VNet/PE를 **자동 관리** (`useMicrosoftManagedNetwork: true`).
고객은 **Customer VNet**(PE 전용)과 **Jumpbox VNet**(VM 전용)을 분리 배치하고 피어링하여 데이터 플레인에 접근합니다.

```
┌──────────────────────────────────────────────────┐
│         Managed VNet (Azure 관리)                │
│  Foundry Account → Project → Agent Service       │
│  PE→Storage  PE→CosmosDB  PE→Search              │
└──────────────────┬───────────┬───────────┬───────┘
                   ↓           ↓           ↓
          Storage Account   Cosmos DB   AI Search
            (Disabled)      (Disabled)   (Disabled)
                   ↑           ↑           ↑
┌──────────────────┴───────────┴───────────┴───────┐
│  Customer VNet (10.1.0.0/16) — PE 전용           │
│  snet-privateendpoints (10.1.0.0/24)             │
│  PE→Foundry  PE→Storage  PE→Cosmos  PE→Search    │
│  Private DNS Zones (7개)                         │
└──────────────────┬───────────────────────────────┘
                   │ VNet Peering (양방향)
┌──────────────────┴───────────────────────────────┐
│  Jumpbox VNet (10.2.0.0/16) — VM 전용            │
│  snet-jumpbox (10.2.0.0/24)                      │
│  ┌───────────────────────────┐                   │
│  │  Windows VM (Public IP)   │ ← RDP             │
│  │  피어링 → PE → Private DNS → 데이터 플레인    │
│  └───────────────────────────┘                   │
│  DNS Zone VNet Links (7개)                       │
└──────────────────────────────────────────────────┘
```

> 같은 리소스에 **PE가 2세트** 생성됩니다:
> - Managed VNet PE (Azure 관리) → Agent가 사용
> - Customer VNet PE (고객 관리) → Jumpbox가 피어링을 통해 사용

### BYO VNet (basic/) vs Managed VNet (basic-managedvnet/) 비교

| | **basic/** (BYO VNet) | **basic-managedvnet/** (Managed VNet) |
|---|---|---|
| Agent VNet | 고객 소유 (subnet delegation) | Azure 자동 관리 |
| Customer VNet | Agent+PE+Jumpbox 통합 (1개) | PE 전용 (Agent/Jumpbox 없음) |
| Jumpbox VNet | 없음 (같은 VNet) | **별도 VNet** (10.2.0.0/16) |
| Customer ↔ Jumpbox | 같은 VNet | **VNet 피어링** |
| Private Endpoint | 고객 VNet에 1세트 | **2세트** (Managed + Customer) |
| Jumpbox → Private 리소스 | VNet 내부 PE 경유 | 피어링 → Customer VNet PE 경유 |
| Public IP | Jumpbox만 | Jumpbox만 |
| Hub-Spoke | ✅ 지원 | ❌ Agent VNet 피어링 불가 |
| 상태 | **GA** | **Preview** |

### 배포되는 리소스

| 카테고리 | 리소스 | 비고 |
|----------|--------|------|
| **AI Foundry** | Account (Managed VNet), Project | `useMicrosoftManagedNetwork: true` |
| **Capability Host** | Project Capability Host (Agents) | 자동 구성 |
| **모델 배포** | GPT-4o, text-embedding-3-large | GlobalStandard SKU |
| **의존 서비스** | Storage, Cosmos DB, AI Search | `publicNetworkAccess: Disabled` |
| **Customer VNet** | VNet (10.1.0.0/16), PE 서브넷, NSG | PE 전용 |
| **Private DNS Zones** | 7개 | Customer VNet + Jumpbox VNet 모두 Link |
| **Customer PE** | 5개 | Foundry, Storage(blob/file), Cosmos, Search |
| **Jumpbox VNet** (선택) | VNet (10.2.0.0/16), Jumpbox 서브넷, NSG | Customer VNet과 피어링 |
| **VNet Peering** (선택) | Customer ↔ Jumpbox (양방향) | Jumpbox에서 PE 접근 |
| **Jumpbox** (선택) | Windows VM + Public IP | RDP → 피어링 → PE → 데이터 플레인 |
| **RBAC** | 13개 역할 할당 | basic과 동일 |

## RBAC 역할 할당 (13개)

basic/ 버전과 동일합니다. 상세 내용은 [basic/README.md](../basic/README.md#rbac-역할-할당-13개)를 참조하세요.

## 사전 요구 사항

Preview Feature 등록이 필요합니다:

```bash
az feature register --namespace Microsoft.CognitiveServices --name AI.ManagedVnetPreview

# 등록 상태 확인 (승인까지 수 시간 소요)
az feature show --namespace Microsoft.CognitiveServices --name AI.ManagedVnetPreview --query "properties.state" -o tsv
```

## 배포

```bash
cd infra-foundry-new/standard/basic-managedvnet

# 기본 배포
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam

# Jumpbox 포함 배포
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters deployJumpbox=true \
               jumpboxAdminPassword='YourP@ssw0rd!'
```

배포 시간: 약 15-20분

## 배포 후 동작 확인

### Agent 테스트

1. [Azure AI Foundry Portal](https://ai.azure.com) 접속 (PC에서 직접)
2. Project (`proj-xxxxxxxx`) 선택
3. **에이전트(Agents)** > **+ 새 에이전트(New Agent)** 클릭
4. 모델 선택 → 테스트 메시지 전송

### 데이터 플레인 확인 (Jumpbox 필요)

> **📌 Note**: Jumpbox는 **Private Networking 환경에서 고객의 온프레미스 PC 환경을 재현(시뮬레이션)** 하기 위해 구성합니다. 실제 프로덕션에서는 ExpressRoute, VPN Gateway 등으로 대체됩니다.

`publicNetworkAccess: Disabled`인 리소스의 데이터를 확인하려면 Jumpbox에 RDP 접속 후:
- `portal.azure.com` → AI Search 인덱스 조회, Cosmos DB 문서 탐색, Storage Blob 목록
- PE를 통한 Private DNS 해석으로 Private IP로 접근

| 작업 | PC에서 | Jumpbox에서 |
|------|:------:|:----------:|
| 리소스 설정 (관리 플레인) | ✅ | ✅ |
| AI Search 인덱스/데이터 (데이터 플레인) | ❌ | ✅ |
| Cosmos DB 문서 탐색 (데이터 플레인) | ❌ | ✅ |
| Storage Blob 목록 (데이터 플레인) | ❌ | ✅ |
| Foundry Portal Agent 생성/실행 | ✅ | ✅ |

## 삭제

```bash
az group delete --name rg-aif-mvnet-swc-dev --yes

az cognitiveservices account purge \
  --name <account-name> \
  --resource-group rg-aif-mvnet-swc-dev \
  --location swedencentral
```

## 제약 사항

- **Preview** — GA 전까지 API/동작이 변경될 수 있음
- **Feature 등록 필요** — `AI.ManagedVnetPreview` 승인 필요 (수 시간 소요)
- **Agent VNet 피어링 불가** — Azure가 관리하는 Agent VNet의 ID를 알 수 없음
- **PE 2세트 비용** — Managed VNet PE (Azure 관리) + 고객 VNet PE (고객 관리)
- **공식 Bicep 샘플** — [18-managed-virtual-network-preview](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/18-managed-virtual-network-preview) 참조
