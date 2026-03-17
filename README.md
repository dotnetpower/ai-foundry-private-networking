# AI Foundry Private Networking

Azure AI Foundry를 프라이빗 네트워크 환경에서 구성하기 위한 **Bicep** 기반 IaC(Infrastructure as Code) 프로젝트입니다.

> **⚠️ AI Foundry New 버전 기준**
>
> 이 프로젝트는 **AI Foundry New 아키텍처** (2025년 4월~)를 기반으로 작성되었습니다.
>
> | 항목 | New 버전 (이 프로젝트) | Legacy 버전 |
> |------|----------------------|-------------|
> | 리소스 타입 | `Microsoft.CognitiveServices/accounts` (kind=AIServices) | `Microsoft.MachineLearningServices/workspaces` |
> | 프로젝트 | `accounts/projects` 하위 리소스 | `workspaces` (kind=Project) |
> | API 버전 | `2025-04-01-preview` | `2024-04-01` |
> | Agent Setup | Standard Agent Setup (Capability Host) | Managed Network |


## 개요

이 프로젝트는 [Microsoft Learn - Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks) 문서를 기반으로 Azure AI Foundry를 **프라이빗 엔드포인트** 기반으로 안전하게 배포합니다.

### 주요 기능

- Azure AI Foundry Account/Project 프라이빗 배포
- Azure OpenAI 서비스 통합 (GPT-5.4, text-embedding-ada-002)
- 5개 Private Endpoint 기반 네트워크 격리
- 7개 Private DNS Zone을 통한 이름 해석
- Azure Bastion을 통한 보안 접속 (선택)
- Linux/Windows Jumpbox VM (선택)
- AAD(Managed Identity) 인증 기반 서비스 간 연결

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Virtual Network (192.168.0.0/16)                     │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Agent Subnet (192.168.0.0/24)                                        │ │
│  │  - Microsoft.App/environments 위임                                    │ │
│  │  - Foundry Agent 런타임 호스팅 (Capability Host)                      │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Private Endpoint Subnet (192.168.1.0/24)                             │ │
│  │  - pe-foundry (Foundry Account)                                       │ │
│  │  - pe-storage-blob, pe-storage-file (Storage)                         │ │
│  │  - pe-cosmos (Cosmos DB)                                              │ │
│  │  - pe-search (AI Search)                                              │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  Jumpbox Subnet (192.168.2.0/24) [선택적 배포]                        │ │
│  │  - vm-jumpbox-win (Windows 11 Pro)                                     │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │  AzureBastionSubnet (192.168.255.0/26) [선택적 배포]                  │ │
│  │  - bastion-host                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 배포 상태 (2026-03-17 검증)

### ✅ 정상 배포되는 리소스

| 카테고리 | 리소스 | 비고 |
|----------|--------|------|
| **네트워크** | VNet, Subnets, NSGs | 192.168.0.0/16 |
| **Private DNS Zones** | 7개 | cognitiveservices, openai, services.ai, search, documents, blob, file |
| **AI Foundry** | Account (AIServices kind) | `cog-{suffix}` |
| **AI Foundry** | Project | `proj-{suffix}` |
| **모델 배포** | GPT-5.4, text-embedding-ada-002 | GlobalStandard SKU |
| **의존 서비스** | Storage Account, Cosmos DB, AI Search | Private Endpoint 연결 |
| **Private Endpoints** | 5개 | foundry, storage-blob, storage-file, cosmos, search |
| **Connections** | 3개 | storage, cosmos, search (AAD 인증) |
| **RBAC** | 9개 역할 할당 | Storage, Cosmos, Search 역할 |
| **Managed Identity** | User-assigned | Foundry Account 연결 |

### ⚠️ 수동 설정 필요

| 리소스 | 상태 | 원인 |
|--------|------|------|
| **Capability Host** | 수동 설정 필요 | Bicep API에서 `virtualNetworkSubnetResourceId` 미지원 |

### ❌ 제한 사항

| 항목 | 상태 |
|------|------|
| Korea Central 리전 | GPT-5.4 GlobalStandard SKU 미지원, Sweden Central 권장 |
| Capability Host IaC | Bicep/Terraform 자동화 불가 (2025-04-01-preview API 기준) |

## 프로젝트 구조

```
.
├── infra-bicep/                    # Bicep 인프라 코드
│   ├── main.bicep                  # 메인 배포 템플릿 (구독 수준)
│   ├── README.md                   # Bicep 배포 가이드
│   ├── modules/
│   │   ├── networking/             # VNet, Subnet, NSG, Private DNS Zones
│   │   ├── ai-foundry/             # Foundry Account, Project, 모델 배포
│   │   ├── dependent-resources/    # Storage, Cosmos DB, AI Search
│   │   ├── private-endpoints/      # Private Endpoints 및 DNS 설정
│   │   └── jumpbox/                # Jumpbox VM, Azure Bastion (선택)
│   └── parameters/                 # 환경별 파라미터 파일
├── src/                            # Python 소스 코드
│   └── visualize/                  # 인프라 시각화
├── scripts/                        # 유틸리티 스크립트
└── docs/                           # 문서
```

## 시작하기

### 사전 요구사항

- [Azure CLI](https://docs.microsoft.com/cli/azure/) 최신 버전
- Azure 구독 및 적절한 권한 (Owner 또는 Contributor + Role Based Access Administrator)

### 리소스 프로바이더 등록

```bash
az provider register --namespace 'Microsoft.CognitiveServices'
az provider register --namespace 'Microsoft.Storage'
az provider register --namespace 'Microsoft.Search'
az provider register --namespace 'Microsoft.Network'
az provider register --namespace 'Microsoft.App'
az provider register --namespace 'Microsoft.DocumentDB'
```

### 배포

```bash
# 1. Azure 로그인
az login
az account set --subscription "<구독-ID>"

# 2. 파라미터 파일 수정
cd infra-bicep
cp parameters/dev.bicepparam parameters/my-env.bicepparam
# 파라미터 수정...

# 3. Bicep 배포
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/my-env.bicepparam
```

**예상 배포 시간**: 약 15-20분

### Capability Host 설정 (수동)

배포 완료 후 Azure Portal에서 Standard Agent Setup을 구성해야 합니다:

1. **Azure Portal** > **AI Foundry** > 배포된 Project 선택
2. **Management** > **Agent setup** 클릭
3. **Standard agent setup** 선택
4. VNet, Agent 서브넷, Storage/Search/Cosmos Connection 설정
5. **Apply** 클릭

자세한 내용은 [Bicep 배포 가이드](infra-bicep/README.md#capability-host-수동-설정-가이드)를 참조하세요.

## 문서

- **[Bicep 배포 가이드](infra-bicep/README.md)**: Bicep 템플릿 배포 및 Capability Host 설정 상세 가이드
- **[Office 파일 RAG 가이드](docs/office-file-rag-guide.md)**: Office 파일 업로드 + AI Search + Playground 시나리오
- **[보안 모범 사례](docs/security-best-practices.md)**: 자격 증명 관리, 네트워크 보안
- **[비용 추정](docs/cost-estimation.md)**: 리소스별 예상 비용 및 절감 방안
- **[AI Search RAG 가이드](docs/ai-search-rag-guide.md)**: RAG 패턴 구현 가이드

## 참고 자료

- [Microsoft Learn - Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
- [GitHub - Foundry Samples (Bicep)](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup)

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
