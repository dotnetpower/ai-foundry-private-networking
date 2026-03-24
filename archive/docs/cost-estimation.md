# AI Foundry Private Networking - 비용 산정서

> **기준일**: 2026년 3월 17일  
> **리전**: Sweden Central  
> **통화**: USD (미국 달러)

## 요약

| 기간 | 예상 비용 (Jumpbox 제외) | 예상 비용 (Jumpbox 포함) |
|------|-------------------------|------------------------|
| **일별 (Daily)** | ~$35 - $50 | ~$55 - $80 |
| **월별 (Monthly)** | ~$1,050 - $1,500 | ~$1,650 - $2,400 |

> 실제 비용은 사용량에 따라 달라질 수 있습니다.

---

## 1. AI 서비스

### 1.1 Azure OpenAI (Sweden Central)

| 모델 | 가격 기준 | 예상 일별 | 예상 월별 |
|------|----------|----------|----------|
| GPT-5.4 (입력) | $5.00 / 1M tokens | $5.00 | $150 |
| GPT-5.4 (출력) | $15.00 / 1M tokens | $7.50 | $225 |
| text-embedding-ada-002 | $0.10 / 1M tokens | $0.50 | $15 |
| **소계** | | **$8.00** | **$240** |

> 일 100만 토큰 사용 가정

### 1.2 Azure AI Search

| 티어 | 월별 고정 비용 | 일별 환산 |
|------|---------------|----------|
| Basic | $73.73 | $2.46 |

---

## 2. 의존 서비스

### 2.1 Azure Cosmos DB

| 항목 | 가격 기준 | 예상 월별 |
|------|----------|----------|
| Serverless (요청당) | $0.25 / 1M RU | $10 - $50 |
| 저장소 | $0.25 / GB | ~$1 |
| **소계** | | **$11 - $51** |

### 2.2 Storage Account

| 항목 | 용량/쿼리 | 가격 | 월별 |
|------|----------|------|------|
| Blob Storage (Hot) | 50 GB | $0.0184/GB | $0.92 |
| File Storage | 10 GB | $0.06/GB | $0.60 |
| 트랜잭션 | 10만 건 | $0.004/만 건 | $0.04 |
| **소계** | | | **$1.56** |

---

## 3. 네트워킹

### 3.1 Private Endpoints

| 항목 | 개수 | 시간당 (각) | 월별 |
|------|-----|------------|------|
| Private Endpoints | 5개 | $0.01 | $36.50 |

> AI Foundry, Storage (blob, file), Cosmos DB, AI Search

### 3.2 Private DNS Zones

| 항목 | 개수 | 월별 (각) | 월별 총액 |
|------|-----|----------|----------|
| Private DNS Zones | 7개 | $0.50 | $3.50 |

### 3.3 VNet

| 항목 | 월별 비용 |
|------|----------|
| Virtual Network | 무료 |
| Subnets | 무료 |
| NSG | 무료 |

---

## 4. Jumpbox (선택적)

> `deployJumpbox = true` 설정 시에만 배포됨

### 4.1 컴퓨팅 (선택)

| 리소스 | SKU | 시간당 | 일별 (24h) | 월별 (730h) |
|--------|-----|--------|-----------|-------------|
| Linux VM | Standard_D2s_v3 | $0.096 | $2.30 | $70.08 |
| Windows VM | Standard_D2s_v3 | $0.096 | $2.30 | $70.08 |
| **소계** | | | **$4.60** | **$140.16** |

### 4.2 Azure Bastion (선택)

| SKU | 시간당 | 일별 (24h) | 월별 (730h) |
|-----|--------|-----------|-------------|
| Basic | $0.19 | $4.56 | $138.70 |
| Standard | $0.35 | $8.40 | $255.50 |

> 기본 배포: Basic SKU

---

## 5. 월별 비용 요약

### 기본 배포 (Jumpbox 제외)

| 카테고리 | 월별 비용 |
|----------|----------|
| Azure OpenAI | $240 |
| AI Search (Basic) | $73.73 |
| Cosmos DB | $11 - $51 |
| Storage | $1.56 |
| Private Endpoints | $36.50 |
| Private DNS Zones | $3.50 |
| **총계** | **$366 - $406** |

### 전체 배포 (Jumpbox 포함)

| 카테고리 | 월별 비용 |
|----------|----------|
| 기본 인프라 | $366 - $406 |
| Linux VM | $70.08 |
| Windows VM | $70.08 |
| Bastion (Basic) | $138.70 |
| **총계** | **$645 - $685** |

---

## 비용 절감 방안

### 1. Jumpbox 최적화

| 방안 | 절감액 (월별) |
|------|-------------|
| Windows VM 제거 | ~$70 |
| VM 사용 시에만 시작 | ~50% |
| Spot VM 사용 | ~60-80% |

### 2. Bastion 최적화

| 방안 | 절감액 (월별) |
|------|-------------|
| Basic SKU 사용 | ~$117 |
| 사용 시에만 시작 | ~50% |

### 3. AI Search 최적화

| 방안 | 절감액 (월별) |
|------|-------------|
| Free 티어 (개발/테스트) | ~$74 |

> Free 티어는 Private Endpoint 미지원

### 4. 개발/테스트 환경

| 방안 | 절감액 |
|------|--------|
| 야간/주말 VM 중지 | ~40% |
| 저사양 SKU 사용 | ~30% |

---

## 주의사항

1. **Korea Central**: GPT-5.4 GlobalStandard SKU 미지원으로 Sweden Central 사용
2. **Cosmos DB**: Serverless 모드로 사용량 기반 과금
3. **Private Endpoints**: 시간당 과금으로 장기 사용 시 비용 누적
4. **Azure OpenAI**: 토큰 사용량에 따라 비용 크게 변동

---

## 참고 자료

- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Azure OpenAI Pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/)
- [Azure AI Search Pricing](https://azure.microsoft.com/pricing/details/search/)
