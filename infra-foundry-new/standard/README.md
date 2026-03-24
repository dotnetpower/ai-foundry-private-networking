# Standard Agent Setup (Private Networking)

Standard Agent Setup은 **프라이빗 네트워크** 환경에서 Foundry Agent Service를 운영합니다.

## 개요

VNet + Private Endpoint 기반으로 모든 트래픽이 Microsoft 백본 네트워크를 통해 전달됩니다.

### 배포되는 리소스

| 카테고리 | 리소스 | 비고 |
|----------|--------|------|
| **네트워크** | VNet, Subnets (4개), NSGs | 192.168.0.0/16 |
| **Private DNS Zones** | 7개 | cognitiveservices, openai, services.ai 등 |
| **AI Foundry** | Account, Project | kind=AIServices |
| **모델 배포** | GPT-4o, text-embedding-ada-002 | GlobalStandard SKU |
| **의존 서비스** | Storage, Cosmos DB, AI Search | Private Endpoint 연결 |
| **Private Endpoints** | 5개 | foundry, storage-blob, storage-file, cosmos, search |
| **RBAC** | 9개 역할 할당 | Managed Identity 기반 |
| **Jumpbox** (선택) | Linux/Windows VM + Bastion | VNet 내부 접속용 |

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                 Virtual Network (192.168.0.0/16)                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Agent Subnet (192.168.0.0/24)                          │   │
│  │  - Microsoft.App/environments 위임                      │   │
│  │  - Capability Host (Standard Agent Setup)               │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Private Endpoint Subnet (192.168.1.0/24)               │   │
│  │  - Foundry, Storage (blob/file), Cosmos DB, AI Search   │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Jumpbox Subnet (192.168.2.0/24) [선택]                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  AzureBastionSubnet (192.168.255.0/26) [선택]           │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 배포

### 1단계: Bicep 인프라 배포

```bash
cd infra-bicep/standard

az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

배포 시간: 약 15-20분

### 2단계: Capability Host 구성 (CLI 자동)

Bicep API에서 `virtualNetworkSubnetResourceId`가 미지원이므로, CLI 스크립트로 Capability Host를 자동 구성합니다.

```bash
# Bicep 배포 출력에서 리소스 그룹 이름 확인 후 실행
./scripts/setup-capability-host.sh --resource-group rg-aifoundry-bicep-dev
```

스크립트가 자동으로:
1. Foundry Account/Project 이름 감지
2. Agent Subnet ID 감지
3. Storage/Cosmos/Search Connection 감지
4. Capability Host 생성 (az rest PUT)
5. 프로비저닝 완료까지 폴링

### 수동 설정 (Portal)

CLI 대신 Azure Portal에서 설정할 수도 있습니다:

1. **AI Foundry Portal** > Project 선택
2. **Management** > **Agent setup**
3. **Standard agent setup** 선택
4. VNet, Agent Subnet, Connection 설정
5. **Apply** 클릭

## 배포 검증

```bash
./scripts/verify-deployment.sh rg-aifoundry-bicep-dev
```

## Jumpbox 옵션

VNet 내부 리소스에 접근하려면 Jumpbox가 필요합니다.

```bash
# Jumpbox 포함 배포
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters deployJumpbox=true deployWindowsJumpbox=true
```

## 삭제

```bash
# 1. 리소스 그룹 삭제
az group delete --name rg-aifoundry-bicep-dev --yes

# 2. Cognitive Services Purge (필수 - 안 하면 재배포 시 subnet 충돌)
az cognitiveservices account purge \
  --name <account-name> \
  --resource-group rg-aifoundry-bicep-dev \
  --location swedencentral
```
