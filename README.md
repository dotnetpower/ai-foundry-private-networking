# AI Foundry Private Networking

Azure AI Foundry를 프라이빗 네트워크 환경에서 구성하기 위한 Terraform 기반 IaC(Infrastructure as Code) 프로젝트입니다.

## 개요

이 프로젝트는 Azure AI Foundry Hub와 Project를 프라이빗 엔드포인트를 통해 안전하게 배포하고, 관련 서비스들을 통합 관리하는 인프라를 제공합니다.

### 주요 기능

- Azure AI Foundry Hub/Project 프라이빗 배포
- Azure OpenAI 서비스 통합 (GPT-4o, text-embedding-ada-002)
- 프라이빗 엔드포인트 기반 네트워크 격리
- API Management를 통한 개발자 포털 제공
- 멀티 리전 구성 (East US + Korea Central)
- Jumpbox VM을 통한 안전한 접근
- Azure Bastion을 통한 보안 접속

## 아키텍처

### 리전 분리 구성

| 리전 | 리소스 |
|------|--------|
| **East US** | AI Foundry Hub/Project, Azure OpenAI, Storage, Key Vault, APIM, VNet |
| **Korea Central** | Jumpbox VMs (Windows/Linux), Bastion Host, VNet Peering |

### 인프라 다이어그램

#### 전체 아키텍처

```mermaid
flowchart LR
    subgraph User["👤 사용자 접근"]
        Portal["Azure Portal"]
    end

    subgraph KRC["🇰🇷 Korea Central"]
        Bastion["🛡️ Bastion"]
        subgraph JumpboxVMs["Jumpbox VMs"]
            WinVM["🖥️ Windows<br/>10.1.1.4"]
            LinuxVM["🐧 Linux<br/>10.1.1.5"]
        end
    end

    subgraph EUS["🌍 East US"]
        subgraph AIServices["AI Foundry Services"]
            Hub["🏠 AI Hub"]
            Project["📁 AI Project"]
        end
        subgraph Backend["Backend Services"]
            OpenAI["🧠 OpenAI"]
            Search["🔍 AI Search"]
            Storage["💾 Storage"]
            KV["🔐 Key Vault"]
        end
    end

    Portal --> Bastion
    Bastion --> WinVM & LinuxVM
    WinVM & LinuxVM -.->|Private Endpoint| Hub
    Hub --> Project
    Project --> OpenAI & Search
    Hub --> Storage & KV
```

#### East US 리전 상세

```mermaid
flowchart TB
    subgraph VNet["🔒 vnet-aifoundry 10.0.0.0/16"]
        subgraph Subnet["snet-ai-foundry"]
            PE1["🔗 PE: AI Hub"]
            PE2["🔗 PE: OpenAI"]
            PE3["🔗 PE: Storage"]
            PE4["🔗 PE: Key Vault"]
            PE5["🔗 PE: AI Search"]
            PE6["🔗 PE: ACR"]
        end
    end

    subgraph AI["🤖 AI Foundry"]
        Hub["🏠 aihub-foundry"]
        Project["📁 aiproj-agents"]
    end

    subgraph OpenAI["🧠 aoai-aifoundry"]
        GPT["💬 GPT-4o"]
        Embed["📊 text-embedding-ada-002"]
    end

    subgraph Store["💾 Storage"]
        SA["📦 staifoundry20260128"]
        ACR["🐳 acraifoundry..."]
    end

    KV["🔐 kv-aif-e8txcj4l"]
    Search["🔍 srch-aifoundry"]

    subgraph Monitor["📊 Monitoring"]
        Log["📈 Log Analytics"]
        AppIns["🔭 App Insights"]
    end

    APIM["🌐 API Management"]

    PE1 -.-> Hub
    PE2 -.-> OpenAI
    PE3 -.-> SA
    PE4 -.-> KV
    PE5 -.-> Search
    PE6 -.-> ACR

    Hub --> Project
    Hub --> OpenAI
    Hub --> Search
    Hub --> SA
    Hub --> KV
    Hub --> ACR
    Project --> AppIns
    APIM --> OpenAI
```

#### Korea Central 리전 상세

```mermaid
flowchart TB
    subgraph VNet["🔒 vnet-jumpbox-krc 10.1.0.0/16"]
        subgraph SubnetBastion["AzureBastionSubnet"]
            Bastion["🛡️ bastion-jumpbox-krc"]
        end
        subgraph SubnetJB["snet-jumpbox 10.1.1.0/24"]
            WinVM["🖥️ vm-jb-win-krc<br/>Private IP: 10.1.1.4<br/>Python, Azure CLI"]
            LinuxVM["🐧 vm-jumpbox-linux-krc<br/>Private IP: 10.1.1.5<br/>Docker, Azure CLI"]
        end
    end

    Peering["🔄 VNet Peering<br/>↔ East US"]

    User["👤 사용자"] --> |Azure Portal| Bastion
    Bastion --> |RDP| WinVM
    Bastion --> |SSH| LinuxVM
    WinVM & LinuxVM --> Peering
    Peering --> |Private Network| EUS["East US AI Services"]
```

### 데이터 흐름도

```mermaid
sequenceDiagram
    participant User as 👤 사용자
    participant Bastion as 🛡️ Azure Bastion
    participant Jumpbox as 🖥️ Jumpbox VM
    participant PE as 🔗 Private Endpoint
    participant Hub as 🏠 AI Hub
    participant Project as 📁 AI Project
    participant OpenAI as 🧠 Azure OpenAI
    participant Search as 🔍 AI Search
    
    User->>Bastion: 1. Azure Portal 접속
    Bastion->>Jumpbox: 2. 보안 터널링
    Jumpbox->>PE: 3. 프라이빗 네트워크 경유
    PE->>Hub: 4. AI Hub 접근
    Hub->>Project: 5. 프로젝트 선택
    
    Note over Project,OpenAI: AI 에이전트 실행
    Project->>OpenAI: 6. GPT-4o 호출
    OpenAI-->>Project: 7. 응답 반환
    
    Note over Project,Search: RAG 패턴 (선택)
    Project->>Search: 8. 문서 검색
    Search-->>Project: 9. 검색 결과
    
    Project-->>Jumpbox: 10. 결과 표시
```

### 네트워크 보안 구성

```mermaid
graph LR
    subgraph Internet["🌐 인터넷"]
        ExtUser["외부 사용자"]
    end
    
    subgraph Azure["☁️ Azure"]
        subgraph Public["공용 접근점"]
            Portal["Azure Portal"]
            APIM_Pub["APIM Gateway"]
        end
        
        subgraph Private["🔒 프라이빗 네트워크"]
            Bastion["Azure Bastion"]
            
            subgraph VNet1["East US VNet"]
                AIServices["AI Services<br/>(Private Only)"]
            end
            
            subgraph VNet2["Korea Central VNet"]
                Jumpbox["Jumpbox VMs"]
            end
            
            VNet1 <--> VNet2
        end
    end
    
    ExtUser -->|"HTTPS"| Portal
    ExtUser -->|"API 호출"| APIM_Pub
    Portal -->|"Bastion 연결"| Bastion
    Bastion -->|"RDP/SSH"| Jumpbox
    Jumpbox -->|"Private Endpoint"| AIServices
    APIM_Pub -->|"Private Backend"| AIServices
    
    style Private fill:#e6f3ff,stroke:#0078D4
    style AIServices fill:#7B2C8C,color:#fff
    style Bastion fill:#107C10,color:#fff
```

### 배포된 주요 리소스 (2026년 1월 28일 기준)

| 카테고리 | 리소스 | 이름/값 |
|----------|--------|---------|
| **리소스 그룹** | Resource Group | `rg-aifoundry-20260128` |
| **네트워크** | VNet (East US) | `vnet-aifoundry` (10.0.0.0/16) |
| | VNet (Korea Central) | `vnet-jumpbox-krc` (10.1.0.0/16) |
| **AI Foundry** | AI Hub | `aihub-foundry` |
| | AI Project | `aiproj-agents` |
| **Azure OpenAI** | OpenAI Account | `aoai-aifoundry` |
| | GPT-4o | `gpt-4o` (2024-11-20) |
| | Embedding | `text-embedding-ada-002` |
| **스토리지** | Storage Account | `staifoundry20260128` |
| | Container Registry | `acraifoundryb658f2ug` |
| **보안** | Key Vault | `kv-aif-e8txcj4l` |
| **Jumpbox** | Windows VM | Private IP: `10.1.1.4` |
| | Linux VM | Private IP: `10.1.1.5` |
| | Bastion | `bastion-jumpbox-krc` |

## 프로젝트 구조

```
.
├── infra/                       # Terraform 인프라 코드
│   ├── main.tf                  # 메인 구성
│   ├── variables.tf             # 변수 정의
│   ├── outputs.tf               # 출력 정의
│   ├── environments/            # 환경별 설정
│   │   ├── dev/                 # 개발 환경
│   │   └── prod/                # 프로덕션 환경
│   ├── modules/                 # Terraform 모듈
│   │   ├── networking/          # VNet, Subnet, NSG
│   │   ├── ai-foundry/          # AI Hub, Project
│   │   ├── storage/             # Storage, Container Registry
│   │   ├── security/            # Key Vault, RBAC
│   │   ├── monitoring/          # Application Insights
│   │   ├── cognitive-services/  # Azure OpenAI, AI Search
│   │   ├── jumpbox-krc/         # Jumpbox VMs (Korea Central)
│   │   └── apim/                # API Management
│   └── scripts/                 # 자동화 스크립트
├── src/                         # Python 소스 코드
│   └── visualize_infrastructure.py  # 인프라 시각화
└── docs/                        # 문서
    └── cost-estimation.md       # 비용 추정
```

## 시작하기

### 사전 요구사항

- [Terraform](https://www.terraform.io/) v1.12.1 이상
- [Azure CLI](https://docs.microsoft.com/cli/azure/) 최신 버전
- Azure 구독 및 적절한 권한
- [uv](https://github.com/astral-sh/uv) (Python 시각화용, 선택사항)

### 배포 방법

1. **Azure 로그인**
   ```bash
   az login
   az account set --subscription "<구독-ID>"
   ```

2. **Terraform 초기화**
   ```bash
   cd infra
   ./scripts/init-terraform.sh local
   ```

3. **배포 실행**
   ```bash
   ./scripts/deploy.sh
   ```

또는 수동으로:
```bash
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve
```

### 인프라 시각화

Python diagrams 라이브러리를 사용하여 인프라 다이어그램을 생성할 수 있습니다:

```bash
cd src
uv run visualize_infrastructure.py
```

## 네트워크 구성

### 프라이빗 DNS 영역

| DNS 영역 | 용도 |
|----------|------|
| `privatelink.api.azureml.ms` | AI Foundry API |
| `privatelink.notebooks.azure.net` | Notebooks |
| `privatelink.blob.core.windows.net` | Blob Storage |
| `privatelink.file.core.windows.net` | File Storage |
| `privatelink.vaultcore.azure.net` | Key Vault |
| `privatelink.openai.azure.com` | Azure OpenAI |
| `privatelink.cognitiveservices.azure.com` | Cognitive Services |
| `privatelink.search.windows.net` | AI Search |
| `privatelink.azurecr.io` | Container Registry |

### Jumpbox 접근

Azure Bastion을 통해 안전하게 Jumpbox에 접근합니다:

1. Azure Portal에서 `bastion-jumpbox-krc` 선택
2. Windows VM (`10.1.1.4`) 또는 Linux VM (`10.1.1.5`) 선택
3. 자격 증명 입력 후 연결

## 비용

예상 월간 비용에 대한 자세한 내용은 [docs/cost-estimation.md](docs/cost-estimation.md)를 참조하세요.

| 시나리오 | 월별 예상 비용 |
|----------|---------------|
| 최소 (유휴 상태) | ~$1,000 |
| 일반 (개발 중) | ~$1,500 |
| 최대 (활발한 사용) | ~$3,600 |

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 기여

버그 리포트, 기능 제안, Pull Request를 환영합니다.
