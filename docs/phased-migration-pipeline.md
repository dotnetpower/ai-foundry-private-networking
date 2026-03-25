# 단계별 구성 파이프라인

E2E Private Networking을 고려한 Azure AI Foundry 인프라의 단계별 구성 및 마이그레이션 전략입니다.

## 배경: Foundry 리소스 vs Hub 리소스

Azure Portal에서 프로젝트 생성 시 두 가지 리소스 타입을 선택할 수 있습니다.

| 항목 | Hub 리소스 (Classic) | Foundry 리소스 (New) |
|------|---------------------|---------------------|
| **ARM 리소스 타입** | `Microsoft.MachineLearningServices/workspaces` (kind: `Hub`) | `Microsoft.CognitiveServices/accounts` (kind: `AIServices`) |
| **프로젝트 타입** | `MachineLearningServices/workspaces` (kind: `Project`) | 동일 account 하위 Project |
| **기반** | Azure ML Workspace 진화형 | Azure AI Services (Cognitive Services) 진화형 |
| **필수 종속 리소스** | Storage + **Key Vault** + ACR(선택) | Storage + **Cosmos DB** + AI Search |
| **Portal 표시** | "Hub" 아이콘 | "Foundry" 아이콘 |
| **상태** | GA (안정) | Preview → GA 진행 중 |

## 네트워크 격리: Managed VNet vs 직접 VNet

### Managed VNet (Classic Hub 전용)

Hub가 Private Endpoint, DNS Zone, VNet을 **자동 생성/관리**합니다.

- VNet 설계, 서브넷 분리, NSG 규칙, PE 생성, DNS Zone 등록을 **전부 Hub가 자동 처리**
- 3가지 격리 모드: `Disabled`, `AllowInternetOutbound`, `AllowOnlyApprovedOutbound`
- 네트워크 전문 인력 없이도 보안 요건 충족 가능
- **단점**: 세밀한 네트워크 제어 어려움, Classic(Hub) 리소스에서만 사용 가능

### 직접 VNet + Private Endpoint (New Foundry)

사용자가 VNet, 서브넷, NSG, PE, DNS Zone을 **직접 구성**합니다.

- 세밀한 네트워크 제어 가능
- 직접 VNet + Private Endpoint + 7개 DNS Zone
- Agent 서브넷 위임 (`Microsoft.App/environments`)
- Portal에서 Agent Setup 시 VNet/Subnet 선택 후 자동 프로비저닝
- **단점**: 구성 복잡도 높음

### 네트워크 격리 지원 매트릭스

```
                  ┌──────────────────────────────────────┐
                  │          네트워크 격리 방식             │
                  ├──────────────┬───────────────────────┤
                  │ Managed VNet │ 직접 VNet + PE         │
┌────────────┬────┼──────────────┼───────────────────────┤
│            │Hub │   ✅ 지원     │   ✅ 지원              │
│ 리소스     │(Cl)│              │                       │
│ 타입       ├────┼──────────────┼───────────────────────┤
│            │Fdy │   ❌ 미지원   │   ✅ 지원              │
│            │(New)│             │                       │
└────────────┴────┴──────────────┴───────────────────────┘
```

## E2E Private Networking 가능 여부

| 구성 | E2E Private | Agent 방식 | 비고 |
|------|:-----------:|-----------|:---------------:|
| **Classic + Managed VNet** | ✅ | Compute Instance 기반 | Hub가 자동 관리 |
| **New Foundry Standard** | ✅ | 프롬프트 기반 Agent | Portal Agent Setup 으로 구성 |
| **New Foundry Hosted Agent** | ❌ (Preview 제한) | Docker 컨테이너 Agent | Account 수준, Public만 |

> **Hosted Agent는 현재 E2E Private Networking이 불가능합니다.** GA 시 VNet 통합이 예상되지만 현재는 `publicNetworkAccess: Enabled` 필수입니다.

## 단계별 구성 파이프라인

E2E Private Networking을 확보하면서 최신 Foundry로 점진적 마이그레이션하는 전략입니다.

### Phase 1: Classic Hub + Managed VNet (현재 권장)

```
📁 infra-foundry-classic/
```

- **목적**: E2E Private Networking 즉시 확보
- **리소스**: Hub (MachineLearningServices) + Managed VNet
- **네트워크**: Hub가 PE/DNS를 자동 관리
- **종속 리소스**: Storage, Key Vault, AI Search(선택), ACR(선택)
- **장점**: 설정 간편, GA 안정성, 프로덕션 즉시 가능
- **접근 방식**: Jumpbox VM(Windows, RDP) → Hub에 접속

### Phase 2: New Foundry Standard (마이그레이션)

```
📁 infra-foundry-new/standard/
```

- **목적**: E2E Private Networking 유지 + 최신 Foundry 기능 활용
- **리소스**: Foundry Account (CognitiveServices, kind: AIServices)
- **네트워크**: 직접 VNet + Private Endpoint + 7개 DNS Zone
- **종속 리소스**: Storage, Cosmos DB, AI Search
- **변경점**: Key Vault → Cosmos DB, Hub → Foundry Account, Managed VNet → 직접 VNet/PE
- **Agent Setup**: Portal에서 VNet/Subnet/Connection 선택 후 프로비저닝

### Phase 3: New Foundry Hosted Agent (GA 대기)

```
📁 infra-foundry-new/hosted/
```

- **목적**: Docker 컨테이너 기반 커스텀 Agent 실행
- **전제 조건**: Hosted Agent의 Private Networking GA 지원
- **현재 제한**: `publicNetworkAccess: Enabled` 필수, VNet/PE 연동 불가
- **종속 리소스**: ACR, Application Insights
- **전환 시점**: Hosted Agent GA + Private Networking 지원 확인 후

## 마이그레이션 호환성 설계

Phase 간 전환을 용이하게 하기 위한 설계 원칙:

| 항목 | 설계 원칙 |
|------|----------|
| **명명 규칙** | 모든 Phase에서 `shortSuffix = take(uniqueString(...), 8)` 사용 |
| **모듈 구조** | 동일한 모듈 분리 패턴 (networking, ai-foundry, dependent-resources 등) |
| **DNS Zone 이름** | `privatelink.*.azure.com` 형식 통일 |
| **OpenAI 모델** | 동일 모델명/SKU (GPT-4o GlobalStandard, text-embedding-ada-002) |
| **파라미터 형식** | `.bicepparam` 파일 구조 통일 |
| **리전** | Sweden Central (Foundry 요구사항) |

## 참고 자료

- [Azure AI Foundry Network Isolation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/network-isolation)
- [Managed VNet Isolation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/managed-network)
- [Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
- [What are hosted agents?](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/hosted-agents)
