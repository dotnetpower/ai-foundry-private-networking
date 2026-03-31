# Standard Agent Setup - Terraform (BYO VNet + Private Networking)

Standard Agent Setup의 Terraform 구현입니다. **BYO VNet(Bring Your Own Virtual Network)** 기반 **프라이빗 네트워크** 환경에서 Foundry Agent Service를 운영합니다.

> Bicep 버전은 [basic-bicep/](../basic-bicep/) 를 참고하세요.

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│ VNet (10.0.0.0/16)                                      │
│  ┌──────────────────┐  ┌──────────────────────────────┐ │
│  │ snet-agent       │  │ snet-privateendpoints        │ │
│  │ 10.0.0.0/24      │  │ 10.0.1.0/24                  │ │
│  │ (App delegation) │  │ PE: Foundry, Storage,        │ │
│  │                  │  │     Cosmos DB, AI Search      │ │
│  └──────────────────┘  └──────────────────────────────┘ │
│  ┌──────────────────┐                                   │
│  │ snet-jumpbox     │  ← Optional                       │
│  │ 10.0.2.0/24      │                                   │
│  └──────────────────┘                                   │
└─────────────────────────────────────────────────────────┘
```

## 사전 요구사항

- Terraform >= 1.5.0
- AzureRM Provider >= 4.0.0
- AzAPI Provider >= 2.0.0
- Azure CLI 로그인 (`az login`)
- Subscription에 Contributor + User Access Administrator 권한

## 배포 방법

```bash
# 1. 초기화
cd infra-foundry-new/standard/basic-terraform
terraform init

# 2. dev 환경 배포
terraform plan -var-file="environments/dev.tfvars" -var="jumpbox_admin_password=YourSecurePass123!"
terraform apply -var-file="environments/dev.tfvars" -var="jumpbox_admin_password=YourSecurePass123!"

# 3. Sweden Central 테스트
terraform plan -var-file="environments/swc-test.tfvars"
terraform apply -var-file="environments/swc-test.tfvars"

# 4. 삭제
terraform destroy -var-file="environments/dev.tfvars"
```

## 모듈 구조

```
basic-terraform/
├── main.tf                          # 메인 (provider, modules 조합)
├── variables.tf                     # 입력 변수
├── outputs.tf                       # 출력값
├── modules/
│   ├── networking/main.tf           # VNet, Subnet, NSG, Private DNS Zones, Peering
│   ├── dependent-resources/main.tf  # Storage Account, Cosmos DB, AI Search
│   ├── ai-foundry/main.tf          # Foundry Account, Project, Models, RBAC (AzAPI)
│   ├── private-endpoints/main.tf    # Private Endpoints + DNS Zone Groups
│   ├── capability-host/main.tf      # Capability Host (AzAPI, preview API)
│   └── jumpbox/main.tf             # Windows VM (optional)
└── environments/
    ├── dev.tfvars                    # 개발 환경
    ├── swc-test.tfvars              # Sweden Central 테스트
    └── kc-test.tfvars               # Korea Central 테스트
```

## AzAPI Provider 사용

Foundry Account, Project, Model Deployment, Connection, Capability Host는 현재 AzureRM에서 지원하지 않는 preview API(`2025-04-01-preview`)를 사용하므로 **AzAPI provider**를 사용합니다.

| 리소스 | Provider | API 버전 |
|--------|----------|----------|
| Foundry Account (AIServices) | AzAPI | 2025-04-01-preview |
| Project | AzAPI | 2025-04-01-preview |
| Model Deployments | AzAPI | 2025-04-01-preview |
| Project Connections | AzAPI | 2025-04-01-preview |
| Capability Host | AzAPI | 2025-04-01-preview |
| VNet, NSG, Subnet | AzureRM | GA |
| Storage, Cosmos DB, AI Search | AzureRM | GA |
| Private Endpoints | AzureRM | GA |
| RBAC Role Assignments | AzureRM | GA |

## Hub-Spoke 연동

Hub VNet이 있는 경우 tfvars에 Hub 정보를 설정하면 자동으로 VNet Peering + DNS Zone Link가 생성됩니다.

```hcl
hub_vnet_id             = "/subscriptions/{sub}/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
hub_vnet_resource_group = "rg-hub"
hub_vnet_name           = "vnet-hub"
```

## 서브넷 리전 제한

| 주소 클래스 | 지원 범위 |
|-------------|----------|
| Class B/C (`172.16.0.0/12`, `192.168.0.0/16`) | 모든 Agent Service 리전 |
| Class A (`10.0.0.0/8`) | 19개 리전만 GA |

기본 템플릿은 `10.0.0.0/16`을 사용합니다. Class A 미지원 리전에서는 `172.16.0.0/16`으로 변경하세요.
