# AI Foundry Private Networking - Terraform Infrastructure

이 디렉토리는 Azure AI Foundry를 프라이빗 네트워킹 환경에서 구성하기 위한 Terraform 코드를 포함합니다.

> **최종 배포**: 2026년 1월 28일  
> **리소스 그룹**: `rg-aifoundry-20260128`

## 폴더 구조

```
infra/
├── main.tf                    # 메인 Terraform 구성
├── variables.tf               # 변수 정의
├── outputs.tf                 # 출력 값
├── environments/              # 환경별 구성
│   ├── dev/                   # 개발 환경
│   │   ├── terraform.tfvars   # 개발 환경 변수
│   │   └── backend.tfvars     # 백엔드 설정
│   └── prod/                  # 프로덕션 환경
├── modules/                   # Terraform 모듈
│   ├── networking/            # VNet, Subnet, NSG, Private DNS
│   ├── security/              # Key Vault, Managed Identity, RBAC
│   ├── storage/               # Storage Account, Container Registry
│   ├── ai-foundry/            # AI Hub, AI Project (azapi)
│   ├── cognitive-services/    # Azure OpenAI, AI Search
│   ├── monitoring/            # Application Insights, Log Analytics
│   ├── jumpbox-krc/           # Jumpbox VMs (Korea Central)
│   └── apim/                  # API Management
└── scripts/                   # 자동화 스크립트
    ├── deploy.sh              # 배포 스크립트
    ├── init-terraform.sh      # 초기화 스크립트
    ├── setup-backend.sh       # 백엔드 설정
    └── validate-terraform.sh  # 검증 스크립트
```

## 모듈 설명

### 1. networking
- Virtual Network 및 서브넷 생성 (10.0.0.0/16)
- Network Security Groups 구성
- Private DNS Zones 설정 (9개)
- Private Endpoints용 네트워크 인프라

### 2. security
- Azure Key Vault: `kv-aif-e8txcj4l`
- Managed Identity: `id-aifoundry`
- RBAC 권한 할당
- Private Endpoints 구성

### 3. storage
- Storage Account: `staifoundry20260128`
- Container Registry: `acraifoundryb658f2ug`
- Private Endpoints 설정 (blob, file)

### 4. ai-foundry
- AI Hub: `aihub-foundry` (azapi_resource)
- AI Project: `aiproj-agents` (azapi_resource)
- Compute Instances 및 Clusters

### 5. cognitive-services
- Azure OpenAI: `aoai-aifoundry`
  - GPT-4o (2024-11-20)
  - text-embedding-ada-002
- Azure AI Search: `srch-aifoundry-7kkykgt6`
- Private Endpoints 설정

### 6. monitoring
- Application Insights: `appi-aifoundry`
- Log Analytics Workspace: `log-aifoundry`
- 메트릭 및 로깅 구성

### 7. jumpbox-krc (Korea Central)
- Windows Jumpbox: `vm-jb-win-krc` (10.1.1.4)
- Linux Jumpbox: `vm-jumpbox-linux-krc` (10.1.1.5)
- Bastion Host: `bastion-jumpbox-krc`
- VNet Peering: Korea Central ↔ East US

### 8. apim
- API Management 개발자 포털
- OpenAI API 프록시
- 3-tier 권한 체계 (Developer/Production/Unlimited)

## 사용 방법

### 1. 초기 설정

```bash
cd infra
chmod +x scripts/*.sh
./scripts/init-terraform.sh local
```

### 2. 배포 (권장)

```bash
./scripts/deploy.sh
```

### 3. 수동 배포

```bash
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve
```

### 4. 리소스 제거

```bash
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

## 현재 배포된 출력값

```
ai_hub_name                = "aihub-foundry"
bastion_name               = "bastion-jumpbox-krc"
deploy_date                = "20260128"
jumpbox_linux_private_ip   = "10.1.1.5"
jumpbox_location           = "koreacentral"
jumpbox_windows_private_ip = "10.1.1.4"
key_vault_name             = "kv-aif-e8txcj4l"
resource_group_name        = "rg-aifoundry-20260128"
storage_account_name       = "staifoundry20260128"
vnet_name                  = "vnet-aifoundry"
```

## 필수 변수

다음 변수들은 `terraform.tfvars`에서 설정됩니다:

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `location` | 메인 리전 | eastus |
| `environment` | 환경 | dev |
| `project_name` | 프로젝트명 | aifoundry |
| `jumpbox_admin_username` | Jumpbox 관리자 | azureuser |
| `jumpbox_admin_password` | Jumpbox 비밀번호 | (필수) |

## 주의사항

1. **민감 정보 관리**: `*.tfvars` 파일에 민감 정보를 저장하지 마세요
2. **State 파일 보안**: Remote backend를 사용하여 상태 파일을 안전하게 관리하세요
3. **비용 최적화**: 사용하지 않는 리소스는 즉시 제거하세요
4. **azapi 프로바이더**: AI Foundry Hub/Project는 azapi를 사용해야 합니다

## 문제 해결

오류 발생 시 [ERROR_SUMMARY.md](ERROR_SUMMARY.md)를 참조하세요.
