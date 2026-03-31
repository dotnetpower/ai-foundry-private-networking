---
description: 'ai-foundry-private-networking: AI Foundry Classic (Hub + Managed VNet) + New Foundry (Standard + Hosted) 배포 지침.'
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
- **기준 날짜**: 항상 현재 날짜 기준으로 설정
- **사실에 근거**: 검증된 정보만 제공, 추측 금지

### 3. 지침 자동 업데이트 규칙
- **오류 해결 시 지침 추가**: Bicep 코드 오류를 해결한 경우, 해결 방법을 이 문서의 "Bicep 코드 작성 지침" 섹션에 자동 추가

### 4. 사용자 인터렉션
- **모호한 요청**: 사용자에게 명확한 추가 정보를 요청
- **단계적 접근**: 복잡한 문제는 단계별로 해결책 제공


## 프로젝트 아키텍처 (세 가지 배포 방식)

### Classic Hub + Managed VNet (`infra-foundry-classic/`)
- **E2E Private Networking**: Hub가 Managed VNet으로 PE/DNS 자동 관리
- **리소스 타입**: `Microsoft.MachineLearningServices/workspaces` (kind: `Hub`)
- **필수 종속 리소스**: Storage, Key Vault
- **네트워크 격리**: Managed VNet (`AllowInternetOutbound` / `AllowOnlyApprovedOutbound`)
- **배포 구조**:
  - `basic/` — Hub + Project + OpenAI + Storage + Key Vault
  - `jumpbox/` — On-prem 시뮬레이션 (Windows VM + Hub VNet Peering)
- **Hub VNet**: `scripts/setup-hub-spoke.sh`로 사전 구성

### Standard Agent Setup (`infra-foundry-new/standard/`)

#### basic/ — BYO VNet (GA, E2E Private)
- **E2E Private Networking**: VNet + Private Endpoint + Private DNS Zone
- **publicNetworkAccess**: `Disabled` (모든 리소스)
- **Capability Host**: Bicep으로 배포 (`ai-foundry/capability-host.bicep`)
- **필요 인프라**: VNet, Storage, Cosmos DB, AI Search, Private Endpoints

#### basic-managedvnet/ — Managed VNet (Preview, E2E Private 불가)
- **E2E Private Networking 불가**: Account `publicNetworkAccess: Enabled` 필수 (Agent Service 동작에 필요)
- **데이터 플레인만 Private**: Storage, Cosmos DB, AI Search는 `publicNetworkAccess: Disabled`
- **2단계 배포 필수**: Bicep으로 구조 선언 → `batchOutboundRules` CLI로 Managed VNet PE 활성화
- **Feature 등록**: `AI.ManagedVnetPreview` Preview Feature 승인 필요
- **Hub-Spoke 미지원**: Azure가 관리하는 Agent VNet의 ID를 알 수 없음

### Hosted Agent Setup (`infra-foundry-new/hosted/`)
- **Private Networking 미지원 (Preview 제한)**
  - `publicNetworkAccess: Enabled` 필수
  - VNet / Private Endpoint 연동 불가
- **컨테이너 기반 Agent**: Docker 이미지를 ACR에 푸시하여 실행
- **Capability Host**: Account 수준, `enablePublicHostingEnvironment: true`
- **필요 인프라**: ACR, Application Insights


## 프로젝트 구조

```
infra-foundry-classic/
├── basic/                       # Classic Hub + Managed VNet (E2E Private)
│   ├── main.bicep               # 메인 배포 템플릿
│   ├── ai-foundry/              # Hub, Project, OpenAI, RBAC
│   ├── dependent-resources/     # Storage, Key Vault
│   └── parameters/
├── jumpbox/                     # On-prem 시뮬레이션 (독립 배포)
│   ├── main.bicep               # subscription scope
│   ├── vm.bicep                 # VNet + NSG + VM + Hub Peering
│   ├── hub-peering.bicep        # Hub → On-prem cross-RG peering
│   └── parameters/
infra-foundry-new/
├── standard/                    # Standard Agent (Private Networking)
│   ├── basic-bicep/             # Bicep 버전
│   │   ├── main.bicep           # 메인 배포 템플릿
│   │   ├── networking/          # VNet, Subnet, NSG, Private DNS Zones
│   │   ├── ai-foundry/          # Foundry Account, Project, Models, RBAC
│   │   ├── dependent-resources/ # Storage, Cosmos DB, AI Search
│   │   ├── private-endpoints/   # Private Endpoints, DNS Zone Groups
│   │   ├── jumpbox/             # Jumpbox VM (선택)
│   │   └── parameters/
│   ├── basic-terraform/         # Terraform 버전
│   │   ├── main.tf              # 메인 (provider, modules 조합)
│   │   ├── variables.tf         # 입력 변수
│   │   ├── outputs.tf           # 출력값
│   │   ├── modules/             # networking, ai-foundry, dependent-resources, private-endpoints, capability-host, jumpbox
│   │   └── environments/        # dev.tfvars, swc-test.tfvars, kc-test.tfvars
├── hosted/                      # Hosted Agent (Public Only)
│   ├── main.bicep               # 메인 배포 템플릿
│   ├── ai-foundry/              # Foundry Account, Project, Models, Capability Host
│   ├── container-registry/      # ACR + AcrPull RBAC
│   ├── monitoring/              # Log Analytics + Application Insights
│   └── parameters/
scripts/
├── setup-hub-spoke.sh           # Hub VNet 생성 (Classic용)
├── setup-capability-host.sh     # Standard Agent Capability Host CLI 구성
├── deploy-hosted-agent.sh       # Hosted Agent 배포
└── verify-deployment.sh         # 배포 검증
```


## Bicep 코드 작성 지침

### 공통
- **Foundry Account kind**: `AIServices`
- **Model SKU**: `GlobalStandard` (Sweden Central 리전)
- **이름 충돌 방지**: `shortSuffix = take(uniqueSuffix, 8)` 사용

### Classic Hub 전용
- **Hub 리소스 타입**: `Microsoft.MachineLearningServices/workspaces` (kind: `Hub`)
- **Hub API 버전**: `2024-10-01`
- **OpenAI API 버전**: `2024-10-01` (GA, preview 사용 금지)
- **publicNetworkAccess**: 모든 리소스 `Enabled`으로 배포 (Hub Managed VNet PE 프로비저닝 완료 후 Disabled 전환)
- **Storage**: `allowSharedKeyAccess: true` (Hub 내부 동작에 필요)
- **Key Vault**: `enablePurgeProtection: true`, `enableRbacAuthorization: true`
- **Managed VNet**: `isolationMode: 'AllowInternetOutbound'` 또는 `'AllowOnlyApprovedOutbound'`

### Standard Agent 전용
- **Account API 버전**: `2025-04-01-preview`
- **publicNetworkAccess**: `Disabled`
- **Agent 서브넷 위임**: `Microsoft.App/environments`
- **Capability Host**: Bicep으로 배포 (`ai-foundry/capability-host.bicep`)
  - Account: `networkInjections` (scenario: agent, subnetArmId)
  - Project: `capabilityHosts` 리소스 (storageConnections, threadStorageConnections, vectorStoreConnections)
- **서브넷 리전 제한**:
  - Class B/C (`172.16.0.0/12`, `192.168.0.0/16`): 모든 Agent Service 리전에서 GA
  - Class A (`10.0.0.0/8`): 19개 리전만 GA (Australia East, Brazil South, Canada East, East US, East US 2, France Central, Germany West Central, Italy North, Japan East, South Africa North, South Central US, South India, Spain Central, Sweden Central, UAE North, UK South, West Europe, West US, West US 3)
  - 기본 템플릿은 `10.0.0.0/16` 사용 → Class A 지원 19개 리전에서 배포 가능

### Hosted Agent 전용
- **Account API 버전**: `2025-04-01-preview`
- **Capability Host API**: `2025-10-01-preview`
- **publicNetworkAccess**: `Enabled` (필수)
- **ACR adminUserEnabled**: `false`
- Docker 이미지: `--platform linux/amd64` 필수

### 해결된 오류 패턴

| 오류 | 원인 | 해결 |
|------|------|------|
| `Storage name too long` | 이름 24자 초과 | `shortSuffix = take(uniqueSuffix, 8)` |
| `GlobalStandard SKU error` | 리전 미지원 | Sweden Central 사용 |
| `Connection category error` | AzureBlob 카테고리 오류 | `AzureStorageAccount` 사용 |
| `virtualNetworkSubnetResourceId not found` | Capability Host API 미지원 | CLI 스크립트 사용 |
| `AcrPullWithMSIFailed` | ACR RBAC 미설정 | Project MI에 AcrPull 역할 할당 |
| `Hub Managed VNet PE 프로비저닝 실패` | 종속 리소스 `publicNetworkAccess: Disabled` | 초기 배포 시 `Enabled`, PE 완료 후 `Disabled` 전환 |
| `Classic Hub + preview API 호환성` | OpenAI `2025-04-01-preview` 사용 | GA 버전 `2024-10-01` 사용 |
| `Cosmos DB Forbidden 403 / 5301` | Cosmos DB Operator는 관리 플레인만 커버 | `Cosmos DB Built-in Data Contributor` (데이터 플레인 RBAC, ID: `00000000-0000-0000-0000-000000000002`) 추가 할당 필수 |
| `Windows VM computerName 15자 초과` | `az vm create` 시 VM name이 computerName으로 사용됨 | `--computer-name` 파라미터로 15자 이내 이름 명시 |
| `Managed VNet Cosmos DB 403 Forbidden` | Account `publicNetworkAccess: Disabled` + Managed VNet PE `Inactive` | Account `publicNetworkAccess: Enabled` 필수 + `batchOutboundRules` CLI로 PE 활성화 |


## 배포 명령어

### Classic Hub + Managed VNet
```bash
# 1. Hub VNet 생성
./scripts/setup-hub-spoke.sh --location swedencentral --env dev

# 2. AI Foundry Basic 배포
cd infra-foundry-classic/basic
az deployment sub create --location swedencentral \
  --template-file main.bicep --parameters parameters/dev.bicepparam

# 3. Jumpbox (On-prem 시뮬레이션) 배포
HUB_VNET_ID=$(az network vnet show -g rg-aif-hub-swc-dev -n vnet-hub-dev --query id -o tsv)
cd ../jumpbox
az deployment sub create --location koreacentral \
  --template-file main.bicep --parameters parameters/dev.bicepparam \
  --parameters hubVnetId="${HUB_VNET_ID}" adminPassword='<비밀번호>'
```

### Standard Agent (Bicep)
```bash
cd infra-foundry-new/standard/basic-bicep
az deployment sub create --location swedencentral \
  --template-file main.bicep --parameters parameters/dev.bicepparam

# Capability Host 구성 (Bicep 후속)
../../scripts/setup-capability-host.sh --resource-group <rg-name>
```

### Standard Agent (Terraform)
```bash
cd infra-foundry-new/standard/basic-terraform
terraform init
terraform plan -var-file="environments/dev.tfvars" -var="jumpbox_admin_password=<비밀번호>"
terraform apply -var-file="environments/dev.tfvars" -var="jumpbox_admin_password=<비밀번호>"

# 삭제
terraform destroy -var-file="environments/dev.tfvars"
```

### Hosted Agent
```bash
cd infra-foundry-new/hosted
az deployment sub create --location swedencentral \
  --template-file main.bicep --parameters parameters/dev.bicepparam

# Docker 빌드 → ACR 푸시 → SDK로 Agent 등록
```

### 리소스 삭제
```bash
az group delete --name <rg-name> --yes
az cognitiveservices account purge --name <account> --resource-group <rg> --location swedencentral
```


## Azure 리소스 명명 규칙

| 리소스 | 패턴 | 예시 |
|--------|------|------|
| Resource Group | `rg-aif-{type}-{region}-{env}` | `rg-aif-classic-basic-swc-dev` |
| Hub VNet RG | `rg-aif-hub-{region}-{env}` | `rg-aif-hub-krc-dev` |
| Jumpbox RG | `rg-aif-jumpbox-{region}-{env}` | `rg-aif-jumpbox-krc-dev` |
| AI Hub | `hub-{suffix}` | `hub-abcd1234` |
| AI Project | `proj-{suffix}` | `proj-abcd1234` |
| OpenAI | `oai-{suffix}` | `oai-abcd1234` |
| Storage | `stc{suffix}` | `stcabcd1234` |
| Key Vault | `kv-{suffix}` | `kv-abcd1234` |

### 리전 약어

| 리전 | 약어 |
|------|------|
| Sweden Central | `swc` |
| Korea Central | `krc` |
| East US | `eus` |
| West Europe | `weu` |


## Azure 리소스 명명 규칙

| 리소스 | 패턴 | 예시 |
|--------|------|------|
| Resource Group | `rg-aifoundry-{type}-{env}` | `rg-aifoundry-bicep-dev` |
| Foundry Account | `cog-{suffix}` | `cog-abcd1234` |
| Project | `proj-{suffix}` | `proj-abcd1234` |
| ACR | `acr{suffix}` | `acrabcd1234` |
| Storage | `st{suffix}` | `stabcd1234` |
| Cosmos DB | `cosmos-{suffix}` | `cosmos-abcd1234` |

## 참고 자료

- [Private Networking for Foundry Agent](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
- [What are hosted agents?](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/hosted-agents)
- [Foundry Samples (Bicep)](https://github.com/microsoft-foundry/foundry-samples)
