# AI Search RAG 설정 가이드

## 개요

이 문서는 Azure AI Foundry에서 AI Search를 사용하여 RAG(Retrieval-Augmented Generation) 패턴을 구현하는 방법을 설명합니다.

## 구성 완료 상태

### 1. 테스트 문서 (Blob Storage)

| 파일명 | 유형 | 카테고리 | 설명 |
|--------|------|----------|------|
| `AI_Foundry_소개.docx` | DOCX | 플랫폼 | Azure AI Foundry 플랫폼 소개 |
| `RAG_패턴_가이드.docx` | DOCX | 개발 가이드 | RAG 패턴 구현 가이드 |
| `보안_가이드.docx` | DOCX | 보안 | 보안 모범 사례 |
| `AI_Foundry_아키텍처.pptx` | PPTX | 아키텍처 | 프라이빗 네트워킹 아키텍처 |
| `개발자_온보딩.pptx` | PPTX | 온보딩 | 개발자 온보딩 가이드 |

**Storage 정보:**
- Storage Account: `staifoundry20260128`
- Container: `documents`
- 접근 방식: Private Endpoint (프라이빗 네트워크)

### 2. AI Search 인덱스

| 항목 | 값 |
|------|-----|
| Search Service | `srch-aifoundry-7kkykgt6` |
| Index Name | `aifoundry-docs-index` |
| Data Source | `aifoundry-blob-datasource` |
| Indexer | `aifoundry-docs-indexer` |
| 문서 수 | 5개 |
| 접근 방식 | Private Endpoint (프라이빗 네트워크) |

**인덱스 필드:**
- `id`: 문서 고유 ID (Base64 인코딩된 storage path)
- `content`: 문서 콘텐츠 (한국어 분석기 적용)
- `title`: 문서 제목
- `category`: 카테고리
- `metadata_storage_path`: 원본 파일 경로
- `metadata_storage_name`: 파일명

### 3. AI Foundry 연결

| 연결 이름 | 유형 | 대상 |
|-----------|------|------|
| `aoai-connection` | Azure OpenAI | `aoai-aifoundry-jnucxsub.openai.azure.com` |
| `aisearch-connection` | Cognitive Search | `srch-aifoundry-7kkykgt6.search.windows.net` |

## AI Foundry Playground에서 RAG 사용하기

### 사전 요구 사항

1. **Jumpbox 접속**: 프라이빗 네트워크이므로 Azure Bastion을 통해 Jumpbox에 접속해야 합니다.

```bash
# Azure Bastion을 통한 Windows Jumpbox 접속
az network bastion rdp \
    --name bastion-jumpbox-krc \
    --resource-group rg-aifoundry-20260128 \
    --target-resource-id $(az vm show -g rg-aifoundry-20260128 -n vm-jb-win-krc --query id -o tsv)
```

### Playground 설정 단계

1. **AI Foundry Portal 접속**
   - Jumpbox에서 브라우저 열기
   - https://ai.azure.com 접속
   - Azure 계정으로 로그인

2. **프로젝트 선택**
   - Hub: `aihub-foundry`
   - Project: `aiproj-agents`

3. **Playground 이동**
   - 왼쪽 메뉴에서 "Playground" 클릭
   - Chat 탭 선택

4. **모델 선택**
   - Deployment: `gpt-4o`

5. **Add your data 설정**
   - "Add your data" 버튼 클릭
   - Data source 선택: **Azure AI Search**
   - 연결: `aisearch-connection` 선택
   - Index: `aifoundry-docs-index` 선택

6. **검색 설정**
   - Search type: **Hybrid (vector + keyword)**
   - Top-k: 5 (검색 결과 개수)
   - Strictness: 3 (1-5, 높을수록 관련성 높은 결과만 반환)

7. **테스트**
   ```
   예시 질문:
   - "Azure AI Foundry의 프라이빗 네트워킹 구성 방법은?"
   - "RAG 패턴에서 AI Search는 어떻게 사용되나요?"
   - "제로 트러스트 보안 원칙이란?"
   - "VNet Peering은 어떻게 구성되어 있나요?"
   ```

## 인덱스 관리

### 인덱서 수동 실행

새 문서를 추가한 후 인덱서를 수동으로 실행하려면:

```bash
# AI Search 관리 키 가져오기
SEARCH_KEY=$(az search admin-key show \
    --service-name srch-aifoundry-7kkykgt6 \
    --resource-group rg-aifoundry-20260128 \
    --query primaryKey -o tsv)

# 인덱서 실행
curl -X POST "https://srch-aifoundry-7kkykgt6.search.windows.net/indexers/aifoundry-docs-indexer/run?api-version=2024-07-01" \
    -H "api-key: $SEARCH_KEY"
```

### 인덱서 상태 확인

```bash
curl -X GET "https://srch-aifoundry-7kkykgt6.search.windows.net/indexers/aifoundry-docs-indexer/status?api-version=2024-07-01" \
    -H "api-key: $SEARCH_KEY"
```

### 검색 테스트

```bash
curl -X POST "https://srch-aifoundry-7kkykgt6.search.windows.net/indexes/aifoundry-docs-index/docs/search?api-version=2024-07-01" \
    -H "api-key: $SEARCH_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "search": "AI Foundry",
        "top": 3,
        "select": "title, content"
    }'
```

## 문서 추가하기

1. **새 문서 준비** (DOCX, PPTX, PDF, TXT 등)

2. **Blob Storage에 업로드** (Jumpbox에서)
   ```bash
   az storage blob upload \
       --account-name staifoundry20260128 \
       --container-name documents \
       --file "새문서.docx" \
       --name "새문서.docx" \
       --auth-mode login
   ```

3. **인덱서 실행** (위 명령 참조)

4. **Playground에서 확인**

## 트러블슈팅

### 문서가 검색되지 않는 경우

1. **인덱서 상태 확인**
   - 인덱서가 성공적으로 실행되었는지 확인
   - 오류 메시지 확인

2. **문서 형식 확인**
   - 지원되는 형식: DOCX, PPTX, PDF, TXT, HTML
   - 암호화된 문서는 인덱싱 불가

3. **권한 확인**
   - AI Search Managed Identity에 Storage Blob Data Reader 역할 필요

### Private Endpoint 접근 문제

1. **DNS 해석 확인**
   - Jumpbox에서 `nslookup staifoundry20260128.blob.core.windows.net`
   - Private IP (10.0.1.x)가 반환되어야 함

2. **VNet Peering 확인**
   - Korea Central ↔ East US 피어링 상태 확인

## 관련 리소스

- [AI Foundry Portal](https://ai.azure.com)
- [Azure AI Search 문서](https://learn.microsoft.com/azure/search/)
- [RAG 패턴 가이드](https://learn.microsoft.com/azure/ai-services/openai/concepts/retrieval-augmented-generation)
