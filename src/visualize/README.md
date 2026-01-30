# AI Foundry Private Networking Visualization

현재 배포된 Azure AI Foundry 인프라를 Python diagrams 라이브러리로 시각화합니다.

## 개요

이 프로젝트는 AI Foundry의 프라이빗 네트워킹 아키텍처를 한눈에 볼 수 있도록 시각화합니다:
- **Korea Central**: Jumpbox VMs, Bastion Host
- **East US**: AI Foundry 메인 인프라 (완전 프라이빗)
- **VNet Peering**: 두 리전 간 안전한 연결

## 설치 및 실행

### 1. 가상환경 생성 및 활성화

```bash
cd src
uv venv
source .venv/bin/activate  # Linux/Mac
# 또는
.venv\Scripts\activate     # Windows
```

### 2. 의존성 설치

```bash
uv add diagrams
```

### 3. 시스템 패키지 설치 (Graphviz)

```bash
# Ubuntu/Debian
sudo apt-get install -y graphviz

# macOS
brew install graphviz

# Windows
# https://graphviz.org/download/ 에서 설치
```

### 4. 시각화 생성

```bash
uv run visualize_infrastructure.py
```

생성된 파일: `ai_foundry_infrastructure.png`

## 아키텍처 구성 요소 (2026년 1월 28일 기준)

### Korea Central Region
- **VNet**: `vnet-jumpbox-krc` (10.1.0.0/16)
- **Jumpbox VMs**:
  - Windows: `vm-jb-win-krc` (Private IP: 10.1.1.4)
  - Linux: `vm-jumpbox-linux-krc` (Private IP: 10.1.1.5)
- **Bastion**: `bastion-jumpbox-krc`
- **NSG**: RDP(3389), SSH(22) 허용

### East US Region
- **VNet**: `vnet-aifoundry` (10.0.0.0/16)
- **Resource Group**: `rg-aifoundry-20260128`

#### AI Foundry Workspace
- AI Hub: `aihub-foundry`
- AI Project: `aiproj-agents`
- Compute Cluster: `cpu-cluster` (Standard_DS3_v2)
- Private Endpoints: `pe-aihub`, `pe-aiproject`

#### Storage
- Storage Account: `staifoundry20260128`
- Container Registry: `acraifoundryb658f2ug`
- Private Endpoints: `pe-storage-blob`, `pe-storage-file`, `pe-acr`

#### Cognitive Services
- Azure OpenAI: `aoai-aifoundry`
  - GPT-4o (2024-11-20)
  - text-embedding-ada-002
- AI Search: `srch-aifoundry-7kkykgt6`
- Private Endpoints: `pe-openai`, `pe-search`

#### Security & Identity
- Key Vault: `kv-aif-e8txcj4l`
- Managed Identity: `id-aifoundry`

#### Monitoring
- Log Analytics: `log-aifoundry`
- Application Insights: `appi-aifoundry`

### 네트워킹
- **VNet Peering**: Korea Central ↔ East US
- **Private DNS Zones** (10개):
  - `privatelink.api.azureml.ms`
  - `privatelink.notebooks.azure.net`
  - `privatelink.blob.core.windows.net`
  - `privatelink.file.core.windows.net`
  - `privatelink.vaultcore.azure.net`
  - `privatelink.cognitiveservices.azure.com`
  - `privatelink.openai.azure.com`
  - `privatelink.search.windows.net`
  - `privatelink.azurecr.io`
  - `privatelink.azure-api.net`

## 접근 방법

### Azure Bastion을 통한 Jumpbox 접속

1. Azure Portal에서 `bastion-jumpbox-krc` 선택
2. 연결할 VM 선택:
   - Windows: `vm-jb-win-krc`
   - Linux: `vm-jumpbox-linux-krc`
3. 자격 증명:
   - 사용자: `azureuser`
   - 비밀번호: (terraform.tfvars에 설정된 값)

### AI Foundry Hub 접근

Jumpbox에서 VNet Peering을 통해 East US의 프라이빗 리소스에 접근:

```bash
# AI Hub 확인
az ml workspace show --name aihub-foundry --resource-group rg-aifoundry-20260128

# Azure AI Studio
https://ai.azure.com
```

## 시각화 결과

생성된 다이어그램 `ai_foundry_infrastructure.png`는 다음을 포함합니다:
- 리전별 리소스 그룹화
- VNet Peering 관계
- Private Endpoints 연결
- 서비스 간 의존성
- 보안 및 모니터링 리소스

## 코드 구조

```
src/
├── visualize_infrastructure.py  # 메인 시각화 스크립트
├── ai_foundry_infrastructure.png  # 생성된 다이어그램
├── pyproject.toml              # 프로젝트 설정
└── .venv/                      # 가상환경
```

## 참고사항

- 다이어그램은 현재 배포 상태를 반영합니다
- Terraform 상태 변경 시 스크립트 재실행 필요
- Korea Central의 Jumpbox를 통해 East US 프라이빗 네트워크 접근
- 모든 AI 서비스는 Private Endpoint로 보호됨

## 업데이트 방법

인프라 변경 후 다이어그램 업데이트:

```bash
cd src
uv run visualize_infrastructure.py
```

## 관련 문서

- [Terraform 인프라 코드](../infra/)
- [비용 산정서](../docs/cost-estimation.md)
- [Azure AI Foundry 문서](https://learn.microsoft.com/azure/ai-studio/)
- [Diagrams 라이브러리](https://diagrams.mingrammer.com/)
