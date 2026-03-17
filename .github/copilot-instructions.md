---
description: 'ai-foundry-private-networking: AI Foundry 프라이빗 네트워킹 기능 구성을 위한 지침.'
applyTo: '**'
---

# ai-foundry-private-networking 지침

## 핵심 원칙 (절대 준수)

### 1. 언어 사용 규칙
- **한국어 의무 사용**: 사용자와의 모든 대화는 반드시 한국어로 진행
- **예외 없음**: 영어 요청이 있어도 한국어로 응답 후 영어 내용 제공

### 2. 보안 및 검증
- **모든 외부 입력은 검증 및 무해화(sanitization) 필수**
- **민감 정보 포함 금지**: 개인정보, 비밀번호, API 키 등
- **기준 날짜**: 항상 현재 날짜 기준으로 설정 (오늘: 2026년 3월 17일)
- **문서 내 이모지 최소화**: 가독성 저하 방지
- **사실에 근거**: 검증된 정보만 제공, 추측 금지

### 3. 지침 자동 업데이트 규칙
- **오류 해결 시 지침 추가**: Bicep 코드 오류를 해결한 경우, 해결 방법을 이 문서의 "Bicep 코드 작성 지침" 섹션에 자동으로 추가
- **업데이트 대상**: deprecated 속성, 지원하지 않는 블록/속성, API 버전별 문법 변경 사항
- **형식**: 간결하고 명확한 문장으로 작성
- **목적**: 동일한 오류 재발 방지 및 코드 품질 향상

### 4. 사용자 인터렉션
- **모호한 요청**: 사용자에게 명확한 추가 정보를 요청
- **단계적 접근**: 복잡한 문제는 단계별로 해결책 제공


## AI Foundry 버전 정보

> **중요**: 이 프로젝트는 **AI Foundry New 아키텍처** (2025년 4월~)를 기반으로 합니다.

| 항목 | New 버전 (이 프로젝트) | Legacy 버전 |
|------|----------------------|-------------|
| 리소스 타입 | `Microsoft.CognitiveServices/accounts` (kind=AIServices) | `Microsoft.MachineLearningServices/workspaces` |
| 프로젝트 | `accounts/projects` 하위 리소스 | `workspaces` (kind=Project) |
| API 버전 | `2025-04-01-preview` | `2024-04-01` |
| Agent Setup | Standard Agent Setup (Capability Host) | Managed Network |


## 프로젝트 구조

```
infra-bicep/
├── main.bicep                   # 메인 배포 템플릿 (구독 수준)
├── README.md                    # 배포 가이드
├── parameters/
│   ├── dev.bicepparam           # 개발 환경 파라미터
│   └── swc-test.bicepparam      # Sweden Central 테스트 파라미터
└── modules/
    ├── networking/              # VNet, Subnet, NSG, Private DNS Zones
    ├── ai-foundry/              # Foundry Account, Project, Connections
    ├── dependent-resources/     # Storage, Cosmos DB, AI Search
    ├── private-endpoints/       # Private Endpoints, DNS Zone Groups
    └── jumpbox/                 # Jumpbox VM, Azure Bastion (선택)
docs/
├── ai-search-rag-guide.md       # RAG 패턴 구현 가이드
├── cost-estimation.md           # 비용 추정
├── office-file-rag-guide.md     # Office 파일 RAG 시나리오
├── security-best-practices.md   # 보안 모범 사례
└── troubleshooting-*.md         # 트러블슈팅 가이드
scripts/
├── generate_test_documents.py   # 테스트 문서 생성
├── jumpbox-offline-deploy.sh    # Jumpbox 배포 스크립트 (Bash)
├── jumpbox-offline-deploy.ps1   # Jumpbox 배포 스크립트 (PowerShell)
└── verify-deployment.sh         # 배포 검증 스크립트
src/visualize/
└── visualize_infrastructure.py  # 인프라 시각화
```

## 배포된 인프라 현황 (2026년 3월 17일 기준)

### 검증된 배포 리전
| 리전 | 상태 | 비고 |
|------|------|------|
| **Sweden Central** | 검증 완료 | GlobalStandard SKU 지원 |
| Korea Central | 미지원 | GPT-5.4 GlobalStandard SKU 미지원 |

### 배포 리소스 (Sweden Central)
| 카테고리 | 리소스 | 이름 패턴 |
|----------|--------|-----------|
| **리소스 그룹** | Resource Group | `rg-aif-swc5` |
| **네트워크** | VNet | `vnet-aifoundry-dev` (192.168.0.0/16) |
| | Agent Subnet | `snet-agent` (192.168.0.0/24) |
| | PE Subnet | `snet-pe` (192.168.1.0/24) |
| **AI Foundry** | Account | `cog-{suffix}` (kind=AIServices) |
| | Project | `proj-{suffix}` |
| **모델 배포** | GPT-5.4 | GlobalStandard SKU |
| | Embedding | text-embedding-ada-002 |
| **의존 서비스** | Storage | `st{suffix}` |
| | Cosmos DB | `cosmos-{suffix}` |
| | AI Search | `srch-{suffix}` |
| **Private Endpoints** | 5개 | foundry, storage-blob, storage-file, cosmos, search |
| **Private DNS Zones** | 7개 | cognitiveservices, openai, services.ai, search, documents, blob, file |


## Bicep 코드 작성 지침

### 필수 설정
- **API 버전**: `2025-04-01-preview` (CognitiveServices 리소스)
- **Foundry Account kind**: `AIServices` (AIServices kind 필수)
- **Model SKU**: `GlobalStandard` (Sweden Central 리전)
- **Agent 서브넷 위임**: `Microsoft.App/environments`

### 검증된 API 버전
```bicep
@description('CognitiveServices API version')
var cognitiveServicesApiVersion = '2025-04-01-preview'

@description('Network API version')
var networkApiVersion = '2024-05-01'

@description('Storage API version')
var storageApiVersion = '2023-05-01'
```

### 해결된 오류 패턴

| 오류 | 원인 | 해결 |
|------|------|------|
| `Storage name too long` | 이름 24자 초과 | `shortSuffix = take(uniqueSuffix, 8)` 사용 |
| `Korea Central SKU error` | Standard SKU 미지원 | `GlobalStandard` SKU, Sweden Central 사용 |
| `Connection category error` | AzureBlob 카테고리 오류 | `AzureStorageAccount` 카테고리 사용 |
| `Missing ResourceId` | Connection metadata 누락 | `ResourceId` 속성 추가 |
| `virtualNetworkSubnetResourceId not found` | Capability Host API 미지원 | 수동 설정 (Portal/CLI) |

### Capability Host 제한사항
- **현재 상태**: Bicep/Terraform 자동화 불가 (2025-04-01-preview API 기준)
- **해결 방법**: Azure Portal에서 수동 설정 필요
- **설정 경로**: AI Foundry Portal > Project > Management > Agent setup > Standard agent setup


## Azure 리소스 명명 규칙

| 리소스 | 패턴 | 예시 |
|--------|------|------|
| Resource Group | `rg-{purpose}-{region}` | `rg-aif-swc5` |
| VNet | `vnet-{purpose}-{env}` | `vnet-aifoundry-dev` |
| Subnet | `snet-{purpose}` | `snet-agent`, `snet-pe` |
| NSG | `nsg-{purpose}-{env}-{subnet}` | `nsg-aifoundry-dev-agent` |
| Foundry Account | `cog-{suffix}` | `cog-jinec4x3` |
| Project | `proj-{suffix}` | `proj-jinec4x3` |
| Storage | `st{suffix}` | `stjinec4x3` |
| Cosmos DB | `cosmos-{suffix}` | `cosmos-jinec4x3` |
| AI Search | `srch-{suffix}` | `srch-jinec4x3` |
| Private Endpoint | `pe-{purpose}-{env}-{resource}` | `pe-aifoundry-dev-foundry` |


## 배포 명령어

### 기본 배포
```bash
cd infra-bicep

# 배포 실행
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam

# 특정 리소스 그룹에 배포
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/swc-test.bicepparam \
  --name my-deployment
```

### 배포 확인
```bash
# 배포 상태 확인
az deployment sub show --name my-deployment --query properties.provisioningState

# 리소스 그룹 내 리소스 확인
az resource list --resource-group rg-aif-swc5 -o table
```

### 리소스 삭제
```bash
# 리소스 그룹 삭제
az group delete --name rg-aif-swc5 --yes

# Cognitive Services 리소스 Purge (Soft Delete 영구 삭제)
az cognitiveservices account purge \
  --name cog-jinec4x3 \
  --resource-group rg-aif-swc5 \
  --location swedencentral
```

> **중요**: Purge 없이 재배포 시 "Subnet already in use" 오류 발생


## 참고 자료

- [Microsoft Learn - Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
- [GitHub - Foundry Samples (Bicep)](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup)
- [Azure Container Apps - Subnet sizing](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks#subnet)
