# AI Foundry Private Networking - 프로젝트 요약

## 프로젝트 개요

Azure AI Foundry를 프라이빗 네트워크 환경에서 구성하기 위한 **Bicep 기반 Infrastructure as Code (IaC) 솔루션**입니다.

> **AI Foundry New 아키텍처** (2025년 4월~)를 기반으로 작성되었습니다.

---

## 배포 상태 (2026년 3월 17일 기준)

### 검증 완료

| 항목 | 결과 | 비고 |
|------|------|------|
| **Bicep 검증** | 완료 | Sweden Central 배포 성공 |
| **배포 시간** | ~17분 | 전체 인프라 프로비저닝 |
| **모든 리소스** | 정상 | 22개 리소스 배포 |

### 배포된 리소스

| 카테고리 | 리소스 | 상태 |
|----------|--------|------|
| **네트워크** | VNet, Subnets (2), NSGs (2) | 정상 |
| **Private DNS Zones** | 7개 | 정상 |
| **AI Foundry** | Account, Project | 정상 |
| **모델 배포** | GPT-5.4, text-embedding-ada-002 | 정상 |
| **의존 서비스** | Storage, Cosmos DB, AI Search | 정상 |
| **Private Endpoints** | 5개 (Foundry, Storage×2, Cosmos, Search) | 정상 |
| **Connections** | 3개 (Storage, Cosmos, Search) | 정상 |
| **RBAC** | 9개 역할 할당 | 정상 |
| **Managed Identity** | User-assigned | 정상 |

### 수동 설정 필요

| 리소스 | 상태 | 해결 방법 |
|--------|------|-----------|
| **Capability Host** | 수동 설정 필요 | Azure Portal에서 Standard Agent Setup 구성 |

---

## 프로젝트 구조

```
.
├── infra-foundry-new/                    # Bicep 인프라 코드
│   ├── main.bicep                  # 메인 배포 템플릿
│   ├── modules/
│   │   ├── networking/             # VNet, Subnet, NSG, Private DNS
│   │   ├── ai-foundry/             # Foundry Account, Project, Connections
│   │   ├── dependent-resources/    # Storage, Cosmos DB, AI Search
│   │   ├── private-endpoints/      # Private Endpoints 및 DNS 설정
│   │   └── jumpbox/                # Jumpbox VM, Bastion (선택)
│   └── parameters/                 # 환경별 파라미터 파일
├── docs/                           # 문서
│   ├── ai-search-rag-guide.md      # RAG 패턴 구현 가이드
│   ├── cost-estimation.md          # 비용 추정
│   ├── office-file-rag-guide.md    # Office 파일 RAG 시나리오
│   └── security-best-practices.md  # 보안 모범 사례
├── scripts/                        # 유틸리티 스크립트
│   ├── jumpbox-offline-deploy.sh   # Jumpbox 배포 스크립트 (Bash)
│   ├── jumpbox-offline-deploy.ps1  # Jumpbox 배포 스크립트 (PowerShell)
│   └── verify-deployment.sh        # 배포 검증 스크립트
└── src/visualize/                  # 인프라 시각화
```

---

## 주요 문서

| 문서 | 설명 |
|------|------|
| **[Bicep 배포 가이드](../infra-foundry-new/README.md)** | Bicep 템플릿 배포 절차 및 Capability Host 설정 |
| **[Office 파일 RAG 가이드](office-file-rag-guide.md)** | Office 파일 업로드 + AI Search + Playground 시나리오 |
| **[보안 모범 사례](security-best-practices.md)** | 자격 증명 관리, 네트워크 보안 |
| **[비용 추정](cost-estimation.md)** | 리소스별 예상 비용 및 절감 방안 |

---

## 빠른 시작

### 1. 배포

```bash
# Azure 로그인
az login
az account set --subscription "<구독-ID>"

# Bicep 배포
cd infra-foundry-new
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

### 2. Capability Host 설정 (수동)

1. **Azure Portal** > **AI Foundry** > 배포된 Project 선택
2. **Management** > **Agent setup** 클릭
3. **Standard agent setup** 선택
4. VNet, Agent 서브넷, Connections 설정
5. **Apply** 클릭

### 3. 삭제

```bash
# 리소스 그룹 삭제
az group delete --name rg-aif-swc5 --yes

# Cognitive Services Purge (필수)
az cognitiveservices account purge \
  --name cog-jinec4x3 \
  --resource-group rg-aif-swc5 \
  --location swedencentral
```

---

## 알려진 제한 사항

| 제한 사항 | 설명 |
|----------|------|
| **Korea Central** | GPT-5.4 GlobalStandard SKU 미지원, Sweden Central 권장 |
| **Capability Host** | Bicep/Terraform 자동화 불가, 수동 설정 필요 |
| **Agent 서브넷** | `Microsoft.App/environments` 위임 필수 |
| **서브넷 IP** | RFC1918 범위만 지원 (10.x, 172.16-31.x, 192.168.x) |

---

## 참고 자료

- [Microsoft Learn - Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
- [GitHub - Foundry Samples (Bicep)](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup)
