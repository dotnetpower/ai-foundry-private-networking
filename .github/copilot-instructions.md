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
- **기준 날짜**: 항상 현재 날짜 기준으로 설정 (오늘: 2026년 1월 30일)
- **문서 내 이모지 최소화**: 가독성 저하 방지
- **사실에 근거**: 검증된 정보만 제공, 추측 금지

### 3. 지침 자동 업데이트 규칙
- **오류 해결 시 지침 추가**: Terraform 코드 오류를 해결한 경우, 해결 방법을 이 문서의 "Terraform 코드 작성 지침" 섹션에 자동으로 추가
- **업데이트 대상**: deprecated 속성, 지원하지 않는 블록/속성, 버전별 문법 변경 사항
- **형식**: 간결하고 명확한 문장으로 작성 (예: "리소스명: 올바른 속성 (~~잘못된 속성~~)")
- **목적**: 동일한 오류 재발 방지 및 코드 품질 향상

### 4. 사용자 인터렉션
- **모호한 요청**: 사용자에게 명확한 추가 정보를 요청
- **단계적 접근**: 복잡한 문제는 단계별로 해결책 제공


## 프로젝트 구조

```
infra/
├── main.tf                      # 메인 Terraform 구성
├── variables.tf                 # 변수 정의
├── outputs.tf                   # 출력 정의
├── environments/
│   └── dev/
│       ├── terraform.tfvars     # 개발 환경 변수
│       └── backend.tfvars       # 백엔드 설정
├── scripts/
│   ├── deploy.sh                # 배포 스크립트
│   ├── import-resources.sh      # Terraform 상태 import 스크립트
│   └── validate-terraform.sh    # 검증 스크립트
└── modules/
    ├── networking/              # VNet, Subnet, NSG, Private DNS
    ├── ai-foundry/              # AI Hub, Project, Connections (azapi)
    ├── storage/                 # Storage Account, Container Registry, ACR DNS Link
    ├── security/                # Key Vault, RBAC, Key Vault PE
    ├── monitoring/              # Application Insights, Log Analytics
    ├── cognitive-services/      # Azure OpenAI, AI Search, Search DNS Link
    ├── jumpbox-krc/             # Korea Central Jumpbox VMs
    └── apim/                    # API Management (개발자 포털)
src/
├── visualize_infrastructure.py  # Python diagrams 시각화
└── README.md                    # 시각화 사용 가이드
```

## 배포된 인프라 현황 (2026년 1월 30일 기준)

### 리전 분리 구성
| 리전 | 리소스 |
|------|--------|
| **East US** | AI Foundry Hub/Project, Azure OpenAI, Storage, Key Vault, APIM, VNet |
| **Korea Central** | Jumpbox VMs (Windows/Linux), Bastion Host, VNet Peering |

### 주요 배포 리소스
| 카테고리 | 리소스 | 이름/값 |
|----------|--------|---------|
| **리소스 그룹** | Resource Group | `rg-aifoundry-20260128` |
| **네트워크** | VNet (East US) | `vnet-aifoundry` (10.0.0.0/16) |
| | VNet (Korea Central) | `vnet-jumpbox-krc` (10.1.0.0/16) |
| **AI Foundry** | AI Hub | `aihub-foundry` (kind=Hub) |
| | AI Project | `aiproj-agents` (kind=Project) |
| **Azure OpenAI** | OpenAI Account | `aoai-aifoundry` |
| | GPT-4o | `gpt-4o` (2024-11-20) |
| | Embedding | `text-embedding-ada-002` |
| **스토리지** | Storage Account | `staifoundry20260128` |
| | Container Registry | `acraifoundryb658f2ug` |
| **보안** | Key Vault | `kv-aif-e8txcj4l` |
| | Managed Identity | `id-aifoundry` |
| **검색** | AI Search | `srch-aifoundry-7kkykgt6` |
| **모니터링** | Log Analytics | `log-aifoundry` |
| | Application Insights | `appi-aifoundry` |
| **Jumpbox** | Windows VM | `vm-jb-win-krc` (Private IP: 10.1.1.4) |
| | Linux VM | `vm-jumpbox-linux-krc` (Private IP: 10.1.1.5) |
| | Bastion | `bastion-jumpbox-krc` |

## Azure AI Foundry + VNet 자동화 핵심 리소스

### 자동화 도구
- **IaC 도구**: Terraform v1.12.1, azurerm ~> 3.80, azapi ~> 1.10
- **시각화**: Diagrams (Python 라이브러리, uv 패키지 매니저)

### 1. 네트워킹 기반 리소스 (상세)

#### 1.1 Virtual Network 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           East US (메인 리전)                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    vnet-aifoundry (10.0.0.0/16)                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  snet-aifoundry (10.0.1.0/24) - Private Endpoints 전용      │   │   │
│  │  │  - pe-aihub (AI Foundry Hub)                                │   │   │
│  │  │  - pe-storage-blob, pe-storage-file (Storage)               │   │   │
│  │  │  - pe-keyvault (Key Vault)                                  │   │   │
│  │  │  - pe-openai, pe-search (Cognitive Services)                │   │   │
│  │  │  - pe-acr (Container Registry)                              │   │   │
│  │  │  - pe-apim (API Management)                                 │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  snet-jumpbox (10.0.2.0/24) - East US Jumpbox (미사용)      │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                          VNet Peering (양방향)
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Korea Central (Jumpbox 리전)                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                  vnet-jumpbox-krc (10.1.0.0/16)                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  snet-jumpbox (10.1.1.0/24) - Jumpbox VMs                   │   │   │
│  │  │  - vm-jb-win-krc (10.1.1.4) - Windows 11 개발 PC            │   │   │
│  │  │  - vm-jumpbox-linux-krc (10.1.1.5) - Ubuntu 22.04           │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  AzureBastionSubnet (10.1.255.0/26) - Bastion Host 전용     │   │   │
│  │  │  - bastion-jumpbox-krc (Public IP 보유)                     │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 1.2 VNet 및 서브넷 상세

| VNet | 리전 | 주소 공간 | 용도 |
|------|------|-----------|------|
| `vnet-aifoundry` | East US | 10.0.0.0/16 | AI Foundry 및 관련 서비스 |
| `vnet-jumpbox-krc` | Korea Central | 10.1.0.0/16 | 개발자 Jumpbox 및 Bastion |

| 서브넷 | VNet | 주소 범위 | 용도 |
|--------|------|-----------|------|
| `snet-aifoundry` | vnet-aifoundry | 10.0.1.0/24 | Private Endpoints (254개 IP) |
| `snet-jumpbox` | vnet-aifoundry | 10.0.2.0/24 | East US Jumpbox (예비) |
| `snet-jumpbox` | vnet-jumpbox-krc | 10.1.1.0/24 | Jumpbox VMs (254개 IP) |
| `AzureBastionSubnet` | vnet-jumpbox-krc | 10.1.255.0/26 | Azure Bastion 전용 (필수 이름) |

#### 1.3 VNet Peering 구성

```
vnet-aifoundry (East US) <──────────────────> vnet-jumpbox-krc (Korea Central)
      │                                                │
      │  peer-main-to-jumpbox                          │  peer-jumpbox-to-main
      │  - allow_forwarded_traffic: true               │  - allow_forwarded_traffic: true
      │  - allow_gateway_transit: false                │  - use_remote_gateways: false
      └────────────────────────────────────────────────┘
```

- **목적**: Korea Central의 Jumpbox에서 East US의 AI Foundry 리소스에 프라이빗 접근
- **양방향 설정**: 양쪽 VNet 모두에 peering 리소스 생성 필요
- **DNS 해석**: Korea Central VNet에도 모든 Private DNS Zone 연결 필요

#### 1.4 Network Security Groups (NSG) 상세

**NSG: `nsg-aifoundry` (East US AI Foundry 서브넷)**

| 우선순위 | 이름 | 방향 | 포트 | 소스 | 대상 | 동작 | 설명 |
|----------|------|------|------|------|------|------|------|
| 100 | AllowAPIMManagement | Inbound | 3443 | ApiManagement | VNet | Allow | APIM 관리 엔드포인트 (필수) |
| 110 | AllowAzureLoadBalancer | Inbound | 6390 | AzureLB | VNet | Allow | Azure LB Health Probe |
| 120 | AllowHTTPS | Inbound | 443 | VNet | * | Allow | HTTPS 트래픽 |
| 130 | AllowAPIMGateway | Inbound | 443 | Internet | VNet | Allow | APIM Gateway |
| 4096 | DenyAllInbound | Inbound | * | * | * | Deny | 기본 거부 |

**NSG: `nsg-jumpbox-krc` (Korea Central Jumpbox 서브넷)**

| 우선순위 | 이름 | 방향 | 포트 | 소스 | 대상 | 동작 | 설명 |
|----------|------|------|------|------|------|------|------|
| 100 | AllowRDPFromBastion | Inbound | 3389 | 10.1.255.0/26 | * | Allow | Bastion → Windows RDP |
| 110 | AllowSSHFromBastion | Inbound | 22 | 10.1.255.0/26 | * | Allow | Bastion → Linux SSH |
| 4096 | DenyAllInbound | Inbound | * | * | * | Deny | 기본 거부 |
| 100 | AllowEastUSVNet | Outbound | * | 10.1.0.0/16 | 10.0.0.0/16 | Allow | East US VNet 접근 |
| 200 | AllowInternet | Outbound | * | * | Internet | Allow | 패키지 설치용 |

#### 1.5 Private DNS Zones 상세

| DNS Zone | 용도 | 연결된 VNet |
|----------|------|-------------|
| `privatelink.api.azureml.ms` | AI Foundry Hub API | East US + Korea Central |
| `privatelink.notebooks.azure.net` | AI Foundry Notebooks | East US + Korea Central |
| `privatelink.blob.core.windows.net` | Storage Blob | East US + Korea Central |
| `privatelink.file.core.windows.net` | Storage File Share | East US + Korea Central |
| `privatelink.vaultcore.azure.net` | Key Vault | East US + Korea Central |
| `privatelink.cognitiveservices.azure.com` | Cognitive Services | East US + Korea Central |
| `privatelink.openai.azure.com` | Azure OpenAI | East US + Korea Central |
| `privatelink.azurecr.io` | Container Registry | East US + Korea Central |
| `privatelink.search.windows.net` | AI Search | East US + Korea Central |
| `privatelink.azure-api.net` | API Management | East US + Korea Central |

**DNS 해석 흐름:**
```
Jumpbox (Korea Central) → Private DNS Zone VNet Link → Private Endpoint IP (East US)
                                                               │
                                                               ▼
                                                    Azure Service (Private)
```

#### 1.6 Azure Bastion 구성

- **SKU**: Standard (Native Client 지원)
- **Public IP**: `pip-bastion-krc` (Static, Standard SKU)
- **기능**:
  - `tunneling_enabled = true`: Native RDP/SSH 클라이언트 지원
  - `ip_connect_enabled = true`: IP 주소로 직접 연결 가능
- **접근 방법**:
  - Azure Portal → Bastion → Connect
  - CLI: `az network bastion rdp --name bastion-jumpbox-krc --resource-group rg-aifoundry-20260128 --target-resource-id <vm-id>`

#### 1.7 트래픽 흐름도

```
[사용자] ──HTTPS──> [Azure Portal/Bastion Public IP]
                            │
                            ▼
              [Azure Bastion (10.1.255.0/26)]
                            │
                      RDP(3389)/SSH(22)
                            │
                            ▼
              [Jumpbox VM (10.1.1.x)]
                            │
                    VNet Peering
                            │
                            ▼
              [Private Endpoint (10.0.1.x)]
                            │
                            ▼
              [Azure Service (AI Foundry, OpenAI, etc.)]
```

#### 1.8 네트워크 보안 핵심 포인트

1. **Zero Trust 접근**: 모든 서비스는 Private Endpoint를 통해서만 접근
2. **Bastion 필수**: Jumpbox VM에 Public IP 없음, Bastion을 통해서만 접근
3. **NSG 최소 권한**: 필요한 포트만 열고 기본 거부
4. **DNS 통합**: 양쪽 VNet에 모든 Private DNS Zone 연결
5. **아웃바운드 제어**: `default_outbound_access_enabled = false`로 기본 아웃바운드 차단

### 2. AI Foundry 핵심 리소스
- **AI Foundry Hub**: 중앙 관리 허브 (azapi, kind=Hub)
- **AI Foundry Project**: 에이전트 개발용 프로젝트 (azapi, kind=Project)
- **OpenAI Connection**: Hub에 연결된 Azure OpenAI 서비스
- **AI Search Connection**: RAG 패턴용 검색 서비스 연결
- **Compute Clusters**: 학습/추론 클러스터 (cpu-cluster)

### 3. 의존 서비스 리소스
- **Azure OpenAI Service**: AI 모델 서비스 (Private Endpoint 필수)
- **Azure Cognitive Services**: 추가 AI 서비스
- **Azure AI Search**: 검색 및 RAG 패턴
- **Storage Account**: Blob/File Storage
- **Key Vault**: 비밀 키 및 인증서 관리
- **Application Insights**: 모니터링 및 로깅
- **Container Registry**: 커스텀 컨테이너 이미지

### 4. 프라이빗 엔드포인트 및 DNS VNet Links (Microsoft 권장 사항 준수)
- AI Hub Private Endpoint (`pe-aihub`)
- Storage Account Private Endpoints (`pe-storage-blob`, `pe-storage-file`)
- Key Vault Private Endpoint (`pe-keyvault`) - security 모듈
- Container Registry Private Endpoint (`pe-acr`) + DNS VNet Link (`link-acr`) - storage 모듈
- Azure OpenAI Private Endpoint (`pe-openai`)
- Azure AI Search Private Endpoint (`pe-search`) + DNS VNet Link (`link-search`) - cognitive-services 모듈
- Cognitive Services Private Endpoint
- Korea Central VNet에 모든 Private DNS Zone VNet Links 연결

### 5. 관리 및 접근 리소스
- **Jumpbox VMs (Korea Central)**: 
  - Windows Jumpbox: `vm-jb-win-krc` (Private IP: 10.1.1.4)
  - Linux Jumpbox: `vm-jumpbox-linux-krc` (Private IP: 10.1.1.5)
- **Bastion Host**: `bastion-jumpbox-krc` (Azure Portal에서 접근)
- **VNet Peering**: Korea Central ↔ East US 연결
- **API Management**: 개발자 포털, 사용자별 권한 부여
- **VPN Gateway/ExpressRoute**: 온프레미스 연결 (선택적)

### 6. API Management (APIM) 구성
- **개발자 포털**: sign_up, sign_in 활성화
- **사용자 그룹**:
  - Developers: 개발 및 테스트 환경 접근
  - AI Engineers: 프로덕션 접근 권한
  - AI Administrators: 무제한 접근 권한
- **제품별 Rate Limit**:
  - Developer: 100 calls/min, 5,000/week
  - Production: 500 calls/min, 50,000/week (승인 필요)
  - Unlimited: 제한 없음 (승인 필요)

### 7. 보안 및 거버넌스 리소스
- **Managed Identity**: 서비스 간 인증
  - System-assigned Identity
  - User-assigned Identity
- **RBAC Roles**: 세밀한 권한 관리
- **Azure Policy**: 규정 준수
- **Defender for Cloud**: 보안 모니터링

### 8. Terraform 구성 요소
- **Resource Group**: 리소스 논리적 그룹화
- **Tags**: 리소스 관리 및 비용 추적
- **Outputs**: 배포 후 필요 정보 출력
- **Variables**: 환경별 구성 파라미터
- **Remote State**: Terraform 상태 파일 관리 (Azure Storage)

## Terraform 코드 작성 지침

### 필수 속성 확인
- **Azure ML Workspace**: `public_network_access_enabled = false` 사용 (~~public_network_access~~)
- **Azure Cognitive Account**: `network_acls` 사용 시 `custom_subdomain_name` 필수
- **Azure Cognitive Deployment**: `scale` 블록 사용 (~~sku~~ 블록 사용 금지)
- **Storage Account**: `public_network_access_enabled = false` 명시
- **Container Registry**: `public_network_access_enabled = false` 명시
- **Storage Container**: `storage_account_name` 사용 (~~storage_account_id~~ 지원 안 함)
- **AI Foundry Hub/Project**: `azurerm_machine_learning_workspace`는 Hub/Project kind 미지원, `azapi_resource` 사용 필수
- **azapi 프로바이더**: 모듈에서 사용 시 `terraform { required_providers { azapi { source = "azure/azapi" } } }` 명시 필요

### 코드 검증 절차
1. **포맷팅**: `terraform fmt -recursive` 실행 (HashiCorp 스타일 준수)
2. **초기화**: `terraform init` 실행
3. **검증**: `terraform validate` 실행
4. **계획**: `terraform plan` 실행 후 리소스 확인
5. **배포**: `terraform apply -auto-approve` 실행
6. **스크립트 사용**: `./scripts/deploy.sh` (권장)

### Azure 리소스 명명 규칙
- VNet: `vnet-{purpose}`
- Subnet: `snet-{purpose}`
- NSG: `nsg-{purpose}`
- Storage: `st{purpose}{date}` (예: `staifoundry20260128`)
- Key Vault: `kv-{purpose}-{suffix}` (예: `kv-aif-e8txcj4l`)
- AI Foundry Hub: `aihub-{purpose}`
- AI Foundry Project: `aiproj-{purpose}`
- APIM: `apim-{purpose}-{suffix}`
- Jumpbox: `vm-jb-{os}-{region}` (예: `vm-jb-win-krc`)

### 해결된 오류 패턴
- **Terraform Output Sensitive**: sensitive 값 참조 시 `sensitive = true` 필수
- **GPT-4o 중복 배포**: 기존 리소스는 `terraform import`로 가져오기
- **RBAC 전파 지연**: Storage Container 생성 전 30-60초 대기 필요
- **AI Foundry Project Private Endpoint**: Project에는 PE 생성 불가, Hub PE가 Project도 커버함
- **AI Foundry Compute Cluster**: AmlCompute는 Project가 아닌 Hub에 생성해야 함
- **OpenAI Connection ApiType**: `metadata`에 `ApiType = "azure"` 필수 (~~누락 시 ValidationError~~)
- **Windows Extension Chocolatey**: choco 설치 후 `C:\ProgramData\chocolatey\bin\choco.exe` 전체 경로 사용 필요
- **random_string 재생성 방지**: `lifecycle { ignore_changes = [special, upper, length] }` 추가 필수
- **Subnet NSG Association Import**: 기존 Azure 리소스를 Terraform으로 관리 시 `terraform import` 필요
- **Private DNS Zone VNet Link**: 각 VNet(East US, Korea Central)에 모든 Private DNS Zone 연결 필요
- **Subnet default_outbound_access_enabled**: 서브넷에 명시적으로 `default_outbound_access_enabled = false` 설정하여 drift 방지
- **AI Foundry Connection AAD 인증**: Azure Policy로 Key 인증 비활성화 시 `authType = "AAD"` 사용, Hub MI에 역할 할당 필요
- **Cognitive Services disableLocalAuth**: 구독 정책으로 강제 시 변경 불가, AAD 인증만 사용 가능
- **Capability Host (Standard Agent Setup)**: 
  - `Microsoft.CognitiveServices/accounts` (kind=AIServices) 사용 필수, `Microsoft.MachineLearningServices/workspaces` 아님
  - Agent 서브넷에 `Microsoft.App/environments` 위임 필수 (서브넷 크기 최소 /24)
  - Project에 CosmosDB, Storage, AI Search Connections 먼저 생성
  - RBAC 역할 할당 완료 후 Capability Host 생성 (순서 중요!)
  - azapi preview API 사용 시 `schema_validation_enabled = false` 추가
  - 삭제 시 Account Purge 필수, 그렇지 않으면 "Subnet already in use" 오류 발생
- **CapabilityHostOperationFailed**: RBAC 미할당, Private Endpoint 미완료, 또는 Connection 설정 오류가 원인