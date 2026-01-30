# AI Foundry Private Networking - 비용 산정서

> **기준일**: 2026년 1월 28일  
> **리전**: East US (메인), Korea Central (Jumpbox)  
> **통화**: USD (미국 달러)

## 요약

| 기간 | 예상 비용 |
|------|----------|
| **일별 (Daily)** | ~$95 - $130 |
| **월별 (Monthly)** | ~$2,850 - $3,800 |

> 실제 비용은 사용량에 따라 달라질 수 있습니다.

---

## 1. 컴퓨팅 리소스

### 1.1 Jumpbox VMs (Korea Central)

| 리소스 | SKU | 시간당 | 일별 (24h) | 월별 (730h) |
|--------|-----|--------|-----------|-------------|
| Windows VM | Standard_D4s_v3 | $0.192 | $4.61 | $140.16 |
| Linux VM | Standard_D4s_v3 | $0.192 | $4.61 | $140.16 |
| **소계** | | | **$9.22** | **$280.32** |

### 1.2 AI Foundry Compute Cluster

| 리소스 | SKU | 시간당 | 일별 | 월별 |
|--------|-----|--------|------|------|
| cpu-cluster (0-4 nodes) | Standard_DS3_v2 | $0.166/node | $0 (min 0) | $0 - $485* |

> *Low Priority VM 사용, 최소 0개 노드로 유휴 시 비용 없음

---

## 2. AI 서비스

### 2.1 Azure OpenAI (East US)

| 모델 | 가격 기준 | 예상 일별 | 예상 월별 |
|------|----------|----------|----------|
| GPT-4o (입력) | $2.50 / 1M tokens | $2.50 | $75 |
| GPT-4o (출력) | $10.00 / 1M tokens | $5.00 | $150 |
| text-embedding-ada-002 | $0.10 / 1M tokens | $0.50 | $15 |
| **소계** | | **$8.00** | **$240** |

> 일 100만 토큰 사용 가정

### 2.2 Azure AI Search

| 티어 | 월별 고정 비용 | 일별 환산 |
|------|---------------|----------|
| Standard (S1) | $245.28 | $8.18 |

> ⚠️ **현재 배포 구성**: Private Endpoint 지원을 위해 Standard SKU 사용. Basic ($73.73)으로 변경 시 월 $171.55 절감 가능.

---

## 3. 네트워킹

### 3.1 Azure Bastion

| SKU | 시간당 | 일별 (24h) | 월별 (730h) |
|-----|--------|-----------|-------------|
| Standard | $0.35 | $8.40 | $255.50 |

### 3.2 VNet Peering (Korea Central ↔ East US)

| 방향 | 가격 (GB당) | 예상 GB/월 | 월별 비용 |
|------|------------|-----------|----------|
| Inbound | $0.035 | 100 GB | $3.50 |
| Outbound | $0.035 | 100 GB | $3.50 |
| **소계** | | | **$7.00** |

### 3.3 Private Endpoints

| 항목 | 개수 | 시간당 (각) | 월별 |
|------|-----|------------|------|
| Private Endpoints | 8개 | $0.01 | $58.40 |

> AI Hub, Storage (blob, file), Key Vault, ACR, OpenAI, AI Search, APIM

### 3.4 Private DNS Zones

| 항목 | 개수 | 월별 (각) | 월별 총액 |
|------|-----|----------|----------|
| Private DNS Zones | 10개 | $0.50 | $5.00 |

---

## 4. 스토리지

### 4.1 Storage Account

| 항목 | 용량/쿼리 | 가격 | 월별 |
|------|----------|------|------|
| Blob Storage (Hot) | 100 GB | $0.0184/GB | $1.84 |
| File Storage | 50 GB | $0.06/GB | $3.00 |
| Transactions | 100만 건 | $0.004/1만 건 | $0.40 |
| **소계** | | | **$5.24** |

### 4.2 Container Registry

| SKU | 스토리지 포함 | 월별 |
|-----|-------------|------|
| Basic | 10 GB | $5.00 |

---

## 5. 보안 및 모니터링

### 5.1 Key Vault

| 항목 | 단가 | 예상 사용량 | 월별 |
|------|-----|------------|------|
| Secrets 작업 | $0.03/1만 작업 | 10만 작업 | $0.30 |
| Keys 작업 | $0.03/1만 작업 | 1만 작업 | $0.03 |
| **소계** | | | **$0.33** |

### 5.2 Application Insights

| 항목 | 단가 | 예상 사용량 | 월별 |
|------|-----|------------|------|
| 데이터 수집 | $2.30/GB | 5 GB | $11.50 |
| 보존 (90일 초과) | $0.12/GB/월 | 0 GB | $0 |
| **소계** | | | **$11.50** |

### 5.3 Log Analytics

| 항목 | 단가 | 예상 사용량 | 월별 |
|------|-----|------------|------|
| 데이터 수집 | $2.76/GB | 5 GB | $13.80 |

---

## 6. API Management

| SKU | 단위 수 | 월별 |
|-----|--------|------|
| Developer | 1 | $49.56 |

> Developer SKU는 SLA 미포함, 프로덕션용은 Basic ($152.91) 이상 권장

---

## 7. AI Foundry Workspace

| 항목 | 월별 |
|------|------|
| AI Hub (Workspace) | $0 (무료) |
| AI Project (Workspace) | $0 (무료) |

> Workspace 자체는 무료, 연결된 리소스에서 비용 발생

---

## 전체 비용 요약

### 고정 비용 (인프라)

| 카테고리 | 일별 | 월별 |
|----------|------|------|
| Jumpbox VMs (2대) | $9.22 | $280.32 |
| Azure Bastion | $8.40 | $255.50 |
| Private Endpoints (8개) | $1.95 | $58.40 |
| Private DNS Zones | $0.17 | $5.00 |
| Storage Account | $0.17 | $5.24 |
| Container Registry | $0.17 | $5.00 |
| Key Vault | $0.01 | $0.33 |
| Application Insights | $0.38 | $11.50 |
| Log Analytics | $0.46 | $13.80 |
| VNet Peering | $0.23 | $7.00 |
| APIM (Developer) | $1.65 | $49.56 |
| AI Search (Standard) | $8.18 | $245.28 |
| **고정 비용 소계** | **$30.99** | **$936.93** |

### 사용량 기반 비용 (AI 서비스)

| 카테고리 | 일별 (예상) | 월별 (예상) |
|----------|------------|------------|
| Azure OpenAI 토큰 사용량 | $8.00 | $240.00 |
| Compute Cluster (사용 시) | $0 - $40 | $0 - $485 |
| **사용량 비용 소계** | **$8 - $48** | **$240 - $725** |

---

## 총 예상 비용

| 시나리오 | 일별 | 월별 |
|----------|------|------|
| **최소 (유휴 상태)** | ~$39 | ~$1,175 |
| **일반 (개발 중)** | ~$55 | ~$1,675 |
| **최대 (활발한 사용)** | ~$130 | ~$3,800 |

---

## 비용 최적화 권장사항

### 1. VM 자동 종료
```bash
# Jumpbox VM 업무 시간 외 자동 종료 설정
# 일 12시간 운영 시 VM 비용 50% 절감 가능
```

### 2. Reserved Instances
- Jumpbox VM: 1년 예약 시 ~40% 절감
- Bastion: 예약 불가

### 3. Compute Cluster 최적화
- `min_node_count = 0` 유지 (유휴 시 비용 없음)
- Low Priority VM 사용 (최대 80% 절감)

### 4. APIM SKU 검토
- 개발: Developer ($49.56)
- 프로덕션: Basic ($152.91) 또는 Standard ($711.70)

### 5. AI Search 티어 검토
- Free: Private Endpoint 미지원 (공용 접근만 가능)
- 개발: Basic ($73.73) - Private Endpoint 지원 ✅
- 프로덕션: Standard S1 ($245.28) - Private Endpoint 지원 ✅

> ⚠️ **중요**: Private Endpoint는 Basic 티어 이상에서만 지원됩니다. Free 티어는 Private Endpoint를 사용할 수 없습니다.

---

## 참고 자료

- [Azure 가격 계산기](https://azure.microsoft.com/pricing/calculator/)
- [Azure OpenAI 가격](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/)
- [Azure VM 가격](https://azure.microsoft.com/pricing/details/virtual-machines/linux/)
- [Azure Bastion 가격](https://azure.microsoft.com/pricing/details/azure-bastion/)

---

*이 문서는 2026년 1월 기준 Azure 공식 가격을 참조하여 작성되었습니다. 실제 청구 금액은 사용량과 지역에 따라 달라질 수 있습니다.*
