# Classic AI Hub vs New Foundry — 기능 비교

> 기준일: 2026-03-25 | 이 프로젝트의 Bicep 코드 및 Azure 공식 문서 기반

## 리소스 구조

| 구분 | Classic AI Hub | New Foundry |
|------|---------------|-------------|
| **Account 리소스** | `Microsoft.MachineLearningServices/workspaces` (kind: `Hub`) | `Microsoft.CognitiveServices/accounts` (kind: `AIServices`) |
| **Project 리소스** | `ML/workspaces` (kind: `Project`, Hub 하위) | `CognitiveServices/accounts/projects` (Account 하위) |
| **OpenAI 리소스** | 별도 `CognitiveServices/accounts` (kind: `OpenAI`) → Hub Connection | Account 자체에 모델 배포 (AIServices 통합) |
| **API 버전** | `2024-10-01` (GA) | `2025-04-01-preview` (Preview) |
| **프로젝트 위치** | `infra-foundry-classic/` | `infra-foundry-new/` |

## 네트워크 격리

| 구분 | Classic AI Hub | New Foundry |
|------|---------------|-------------|
| **Private Networking** | ✅ E2E Private 가능 | Standard: ✅ 가능 / Hosted: ❌ 불가 |
| **네트워크 방식** | Hub Managed VNet (자동 PE 관리) | Standard: VNet + 수동 PE / Hosted: Public Only |
| **PE 자동 프로비저닝** | ✅ Hub가 `outboundRules`로 Storage/KV/OpenAI/Search PE 자동 생성 | ❌ 직접 구성 |
| **배포 시 `publicNetworkAccess`** | Storage/KV/OpenAI: 초기 `Enabled` 필수 (Managed VNet PE 프로비저닝 때문) | Standard: `Disabled`로 배포 가능 / Hosted: `Enabled` 필수 |
| **Jumpbox 접근** | Spoke VNet PE + VNet Peering | Standard: 동일 패턴 / Hosted: 불필요 |

## 필수 종속 리소스

| 리소스 | Classic AI Hub | New Foundry (Standard) | New Foundry (Hosted) |
|--------|---------------|----------------------|---------------------|
| Storage Account | ✅ 필수 | ✅ 필수 | ❌ |
| Key Vault | ✅ 필수 | ❌ | ❌ |
| Azure OpenAI | ✅ 별도 생성 | ✅ Account 내장 | ✅ Account 내장 |
| AI Search | 선택 (RAG) | ✅ 필수 (Agent) | ❌ |
| Cosmos DB | 선택 (Agent) | ✅ 필수 (Agent 스레드) | ❌ |
| ACR | ❌ | ❌ | ✅ 필수 (Docker 이미지) |
| Application Insights | ❌ | ❌ | ✅ 필수 |

## Agent / Capability Host

| 구분 | Classic AI Hub | New Foundry |
|------|---------------|-------------|
| **Agent 방식** | Portal Knowledge + Playground + SDK 직접 호출 | Standard: 프롬프트 기반 (내장 도구) / Hosted: 컨테이너 기반 (Docker) |
| **Capability Host** | 불필요 (Managed VNet이 대체) | Standard: 불필요 (Portal에서 Agent Setup) / Hosted: Account 수준 (`enablePublicHostingEnvironment`) |
| **Agent 서브넷 위임** | 불필요 | Standard: `Microsoft.App/environments` 위임 필요 |
| **Agent 스레드 저장소** | 없음 (자체 관리) | Cosmos DB |

## Portal (ai.azure.com) 기능

> Classic = Foundry (classic) 포탈의 Hub-based 프로젝트, New = Foundry 포탈의 Foundry 프로젝트
> 양쪽 모두 지원하는 기능은 ✅로 표시, 한쪽만 지원하는 기능은 O / X로 표시

### 양쪽 모두 지원

| 기능 | Classic AI Hub | New Foundry | 근거 |
|------|---------------|-------------|------|
| **Model Playground (Chat)** | ✅ Chat Playground | ✅ Model Playground (최대 3개 비교, 도구 통합) | [Playgrounds](https://learn.microsoft.com/en-us/azure/foundry/concepts/concept-playgrounds) |
| **Images Playground** | ✅ DALL-E | ✅ gpt-image-1, Stable Diffusion, FLUX 등 | [Images](https://learn.microsoft.com/en-us/azure/foundry/concepts/concept-playgrounds#images-playground) |
| **Video Playground** | ✅ Sora-2 (Preview) | ✅ Sora-2 (Preview) | [Video](https://learn.microsoft.com/en-us/azure/foundry/concepts/concept-playgrounds#video-playground) |
| **Agents Playground** | ✅ v1 (Preview, Assistants API) | ✅ v2 (GA, Responses API) + Tracing/Eval | [Agents](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#new-in-the-current-portal) |
| **Code Interpreter** | ✅ Agents 내 도구 | ✅ Model Playground + Agents 도구 | [Code Interpreter](https://learn.microsoft.com/en-us/azure/foundry/concepts/concept-playgrounds#generate-and-interpret-code) |
| **Knowledge (RAG)** | ✅ 자동 벡터 인덱싱 | ✅ Foundry IQ 통합 (Preview) | [Foundry IQ](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/what-is-foundry-iq) |
| **Model Catalog** | ✅ OpenAI + Marketplace + Managed Compute | ✅ Foundry Direct Models 확장 | [Feature Comparison](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#available-in-both-portals) |
| **Fine-tuning** | ✅ GPT 파인튜닝 | ✅ 동일 | [Feature Comparison](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#available-in-both-portals) |
| **Evaluations** | ✅ 기본 평가 | ✅ AgentOps 자동 평가 (향상됨) | [Feature Comparison](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#available-in-both-portals) |
| **Tracing** | ✅ 좌측 메뉴 | ✅ Operate > Tracing (Agent 추적 강화) | [Navigate](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#navigate-the-portal) |
| **Content Understanding** | ✅ | ✅ | [Project Types](https://learn.microsoft.com/en-us/azure/foundry-classic/what-is-foundry#which-type-of-project-do-i-need) |
| **Content Safety / Guardrails** | ✅ Guardrails + controls | ✅ Operate > Compliance | [Navigate](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#navigate-the-portal) |
| **Quota 관리** | ✅ Management Center | ✅ Operate > Quota | [Navigate](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#navigate-the-portal) |
| **Connected Resources** | ✅ Management Center | ✅ Operate > Admin | [Navigate](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#navigate-the-portal) |
| **Serverless API** | ✅ MaaS | ✅ Foundry Direct Models | [Terminology](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#terminology-mapping) |
| **Deployments 관리** | ✅ Models + endpoints | ✅ Build > Models | [Navigate](https://learn.microsoft.com/en-us/azure/foundry/how-to/navigate-from-classic#navigate-the-portal) |
| **VS Code 통합** | ✅ Compute Instance 원격 | ✅ Open in VS Code for the Web | [VS Code](https://learn.microsoft.com/en-us/azure/foundry/concepts/concept-playgrounds#open-in-vs-code-capability) |
| **Monitoring** | ✅ App Insights | ✅ Agent 전용 메트릭 | [Monitoring](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/how-to-monitor-agents-dashboard) |

### Classic에서만 지원 (New에서 X)

| 기능 | Classic | New | 설명 | 근거 |
|------|---------|-----|------|------|
| **Prompt Flow** | O | X | 비주얼 프롬프트 오케스트레이션 (Hub-based 전용) | [Project Types](https://learn.microsoft.com/en-us/azure/foundry-classic/what-is-foundry#which-type-of-project-do-i-need) |
| **Compute Instance** | O | X | Managed VNet 내 VM (Jupyter, VS Code 원격) | [Computing](https://learn.microsoft.com/en-us/azure/foundry/concepts/architecture#computing-infrastructure) |
| **Batch Endpoint** | O | X | 대량 추론 | [Architecture](https://learn.microsoft.com/en-us/azure/foundry/concepts/architecture#computing-infrastructure) |

### New에서만 지원 (Classic에서 X)

| 기능 | Classic | New | 설명 | 근거 |
|------|---------|-----|------|------|
| **모델 비교 (Compare)** | X | O | 최대 3개 모델 동시 비교 | [Compare](https://learn.microsoft.com/en-us/azure/foundry/concepts/concept-playgrounds#compare-models) |
| **Agent Builder** | X | O | Prompt Agent No-code 생성/테스트/배포 | [Agent Types](https://learn.microsoft.com/en-us/azure/foundry/agents/overview#prompt-agents) |
| **Workflow** | X | O | 멀티에이전트 오케스트레이션 (Preview) | [Workflow](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/workflow) |
| **Agent Publishing** | X | O | Teams, M365 Copilot, Entra Agent Registry | [Publishing](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/publish-agent) |
| **Agent Memory** | X | O | 대화 간 컨텍스트 유지 (Preview) | [Memory](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/what-is-memory) |
| **Tool Catalog** | X | O | 1,400+ 도구 (GA) | [Tool Catalog](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/tool-catalog) |

## Identity / RBAC

| 구분 | Classic AI Hub | New Foundry |
|------|---------------|-------------|
| **Identity 타입** | SystemAssigned (Hub MI + Project MI) | Standard: SystemAssigned / Hosted: SystemAssigned |
| **OpenAI RBAC** | `Cognitive Services OpenAI Contributor` on 별도 리소스 | Account 자체에 권한 (동일 리소스) |
| **Storage RBAC** | Hub MI에 `Storage Blob Data Contributor` | Project MI에 동일 |
| **Key Vault RBAC** | Hub MI에 `Key Vault Administrator` | 불필요 (KV 없음) |
| **Search RBAC** | Hub/Project MI에 `Search Index Data Contributor` + Search MI에 `OpenAI User` | 동일 패턴 |

## 현재 안정성

| 구분 | Classic AI Hub | New Foundry |
|------|---------------|-------------|
| **API 상태** | ✅ GA (`2024-10-01`) | ⚠️ Preview (`2025-04-01-preview`) |
| **프로덕션 권장** | ✅ | ❌ |
| **Private Networking** | ✅ 검증 완료 | Standard: Portal Agent Setup 으로 구성, ⚠️ Preview |
| **이 프로젝트 동작** | ✅ 정상 | ❌ 비정상 (README에 명시) |

## 선택 가이드

| 요구사항 | 권장 |
|---------|------|
| E2E Private Networking 필수 | **Classic AI Hub** |
| Azure Policy로 public 차단 환경 | **Classic AI Hub** + Policy Exemption |
| 최신 Agent Builder / Tracing 필요 | **New Foundry** (Preview 감수) |
| 컨테이너 기반 커스텀 Agent | **New Foundry Hosted** (Public 환경만) |
| 프로덕션 안정성 우선 | **Classic AI Hub** |
| OpenAI + 오픈소스 모델 통합 | **New Foundry** |