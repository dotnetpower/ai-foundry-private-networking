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
| Account publicNetworkAccess | `Disabled` | **`Enabled` (필수)** |
| E2E Private Networking | **✅ 가능** | **❌ 불가 (Preview 제한)** |
| 배포 방식 | Bicep 단독 | **Bicep + CLI 후속** (2단계) |
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
| **App Gateway** (선택) | Application Gateway v2 | 온프레미스 리소스 접근용 |
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

# Application Gateway 포함 배포 (온프레미스 연동)
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters deployAppGateway=true
```

배포 시간: 약 15-20분

### Application Gateway 후속 작업

Application Gateway를 배포한 경우, 다음 후속 작업이 필요합니다:

1. **Backend Pool 구성** — Azure Portal > Application Gateway > Backend pools > 온프레미스 리소스 IP/FQDN 추가
2. **Managed VNet outbound rule 추가** — App Gateway에 대한 PE를 Managed VNet에 등록:
   ```bash
   az rest --method PUT \
     --url "https://management.azure.com${ACCOUNT_ID}/managedNetworks/default/outboundRules/appgw-rule?api-version=2025-10-01-preview" \
     --body '{"properties":{"type":"PrivateEndpoint","destination":{"serviceResourceId":"<APP_GW_RESOURCE_ID>","subresourceTarget":"appGateway"},"category":"UserDefined"}}'
   ```
3. **batchOutboundRules 재실행** — 새 outbound rule을 포함하여 PE 활성화

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

## 트러블슈팅

### 1. Cosmos DB 403 Forbidden — Agent Service 방화벽 차단

**증상**: Foundry Portal에서 Agent 로딩 시 `Error loading your agents. Response status code does not indicate success: Forbidden (403)` 오류. `Reason: Request originated from IP 51.12.148.189 through public internet. This is blocked by your Cosmos DB account firewall settings.`

**원인**: Agent Service는 Managed VNet 내부 PE가 아닌 **public IP**로 Cosmos DB에 접근. Cosmos DB `publicNetworkAccess: Disabled`이면 차단됨.

**해결**:
```bash
# Cosmos DB publicNetworkAccess 활성화 + Azure 데이터센터 IP 허용
az cosmosdb update --name <cosmos-name> --resource-group <rg-name> \
  --ip-range-filter "0.0.0.0" \
  --public-network-access ENABLED
```

> `0.0.0.0`은 Azure 데이터센터 내부 IP를 모두 허용하는 특수 규칙입니다.

### 2. AI Search "Sorry, you do not have permissions to view this resource"

**증상**: Foundry Portal에서 AI Search 인덱스 연결 시 권한 오류.

**원인**: 로그인한 사용자 계정에 AI Search RBAC이 없음 + `publicNetworkAccess: Disabled`로 포털 접근 차단.

**해결**:
```bash
USER_OID=$(az ad signed-in-user show --query id -o tsv)
SEARCH_ID=$(az search service show --name <search-name> --resource-group <rg-name> --query id -o tsv)

# 사용자 RBAC
az role assignment create --assignee "$USER_OID" --role "Search Index Data Contributor" --scope "$SEARCH_ID"
az role assignment create --assignee "$USER_OID" --role "Search Service Contributor" --scope "$SEARCH_ID"

# publicNetworkAccess 활성화 (포탈 접근용)
az search service update --name <search-name> --resource-group <rg-name> --public-network-access enabled
```

### 3. Storage 권한 오류 — 사용자 RBAC 미할당

**증상**: Foundry Portal에서 Storage 리소스 접근 시 권한 오류.

**해결**:
```bash
USER_OID=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ID=$(az storage account show --name <storage-name> --resource-group <rg-name> --query id -o tsv)

az role assignment create --assignee "$USER_OID" --role "Storage Blob Data Contributor" --scope "$STORAGE_ID"
az role assignment create --assignee "$USER_OID" --role "Storage File Data Privileged Contributor" --scope "$STORAGE_ID"
```

### 4. "API key provided for endpoint is invalid or has been revoked"

**증상**: Foundry Portal에서 AI Search 인덱스 생성 시 `The API key provided for endpoint 'https://cog-xxx.openai.azure.com/' is invalid or has been revoked.`

**원인**: AI Services 계정의 `disableLocalAuth: true` — API Key 인증이 비활성화되어 있음. Foundry Portal 인덱스 생성 기능이 내부적으로 API Key를 사용.

**해결**:
```bash
# disableLocalAuth 해제 (Azure Policy가 차단할 수 있음)
az cognitiveservices account update --name <account-name> --resource-group <rg-name> \
  --custom-domain <account-name> --api-properties "{\"disableLocalAuth\":false}"
```

> ⚠️ Azure Policy에 의해 `disableLocalAuth: false` 전환이 차단될 수 있습니다. 이 경우 Policy 예외를 요청하거나, RBAC 기반(Managed Identity) 인증만 사용하세요.

### 5. AI Search System MI — Storage/AI Services RBAC 부재

**증상**: AI Search가 인덱싱 시 Storage Blob 또는 AI Services(임베딩)에 접근 실패.

**해결**:
```bash
SEARCH_PRINCIPAL=$(az search service show --name <search-name> --resource-group <rg-name> --query "identity.principalId" -o tsv)
STORAGE_ID=$(az storage account show --name <storage-name> --resource-group <rg-name> --query id -o tsv)
ACCOUNT_ID=$(az cognitiveservices account show --name <account-name> --resource-group <rg-name> --query id -o tsv)

# AI Search MI → Storage
az role assignment create --assignee "$SEARCH_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Reader" --scope "$STORAGE_ID"

# AI Search MI → AI Services (임베딩 모델용)
az role assignment create --assignee "$SEARCH_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services OpenAI User" --scope "$ACCOUNT_ID"
```

### 6. Managed VNet PE가 Inactive 상태로 유지

**증상**: `batchOutboundRules` API 호출은 Succeeded이지만, Outbound Rules의 PE 상태가 `Inactive`로 유지.

**원인**: Preview 한계 — Managed VNet PE가 실제로 프로비저닝되지 않음. `provisionManagedNetwork` 액션을 실행해도 PE 상태 변화 없음.

**영향**: Agent Service가 Managed VNet PE를 통해 Storage/Cosmos/Search에 접근할 수 없음 → 의존 리소스의 `publicNetworkAccess`를 Enabled로 전환하여 우회해야 함.

**우회**:
```bash
# 의존 리소스 publicNetworkAccess 활성화
az cosmosdb update --name <cosmos-name> --resource-group <rg-name> \
  --public-network-access ENABLED --ip-range-filter "0.0.0.0"

az search service update --name <search-name> --resource-group <rg-name> \
  --public-network-access enabled

az storage account update --name <storage-name> --resource-group <rg-name> \
  --public-network-access Enabled
```

> 이 우회 방법은 E2E Private Networking을 포기하는 것입니다. 완전한 Private Networking이 필요하면 [basic-bicep/](../basic-bicep/) (BYO VNet) 방식을 사용하세요.

## 제약 사항

> ⚠️ **E2E Private Networking 불가** — 공식 `sample_mvnet.json`에 "There is no e2e secured set-up with this template"로 명시. 완전한 private networking이 필요하면 [basic/](../basic/) (BYO VNet) 방식을 사용하세요.

- **Account `publicNetworkAccess: Enabled` 필수** — Agent Service가 Account 컨트롤 플레인을 통해 동작하므로 Disabled로 전환 불가. 데이터 플레인(Storage/Cosmos/Search)만 private
- **의존 리소스도 `publicNetworkAccess: Enabled` 필요** — Managed VNet PE가 Inactive 상태로 유지되므로, Cosmos DB/AI Search/Storage 모두 public 접근을 허용해야 Agent Service가 동작함
- **사용자 RBAC 별도 할당 필요** — Bicep/스크립트가 시스템 MI만 할당. Foundry Portal 사용을 위해 로그인 사용자에게 Storage, AI Search, AI Services RBAC 수동 할당 필요
- **AI Search MI RBAC 필요** — AI Search 인덱서 사용 시 Search MI에 Storage Blob Data Reader, Cognitive Services OpenAI User 역할 할당 필요
- **2단계 배포 필수** — Bicep으로 Managed VNet 구조 선언 후, `batchOutboundRules` CLI를 별도 실행해야 Managed VNet PE가 활성화됨 (Bicep만으로는 `Inactive` 상태 유지)
- **Preview** — GA 전까지 API/동작이 변경될 수 있음
- **Feature 등록 필요** — `AI.ManagedVnetPreview` 승인 필요 (수 시간 소요)
- **Agent VNet 피어링 불가** — Azure가 관리하는 Agent VNet의 ID를 알 수 없음 → Hub-Spoke 구성 불가
- **PE 2세트 비용** — Managed VNet PE (Azure 관리) + 고객 VNet PE (고객 관리)
- **공식 Bicep 샘플** — [18-managed-virtual-network-preview](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/18-managed-virtual-network-preview) 참조
