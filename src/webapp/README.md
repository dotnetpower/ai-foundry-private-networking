# AI Foundry RAG Chat 웹앱

[azure-search-openai-demo](https://github.com/Azure-Samples/azure-search-openai-demo) 패턴을 기반으로 한 경량 RAG 챗봇입니다.
`infra-foundry-classic/basic` 인프라(Hub + Managed VNet)와 연동됩니다.

## 아키텍처

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Browser    │────▶│  Quart App   │────▶│  Azure OpenAI   │
│  (HTML/JS)  │◀────│  (Python)    │     │  (GPT-4o)       │
└─────────────┘     └──────┬───────┘     └─────────────────┘
                           │
                    ┌──────▼───────┐     ┌─────────────────┐
                    │  AI Search   │◀────│  Blob Storage   │
                    │  (Vector +   │     │  (RAG 문서)      │
                    │   Semantic)  │     └─────────────────┘
                    └──────────────┘
```

### 흐름
1. 사용자가 질문 입력
2. `text-embedding-ada-002`로 쿼리 임베딩 생성
3. AI Search에서 벡터 + 시맨틱 하이브리드 검색 (top-5)
4. 검색된 소스 문서를 컨텍스트로 GPT-4o에 전달
5. 소스 인용 포함 답변 + 후속 질문 3개 생성

## 사전 조건

1. `infra-foundry-classic/basic` 배포 완료
2. **AI Search** 리소스 배포 (Bicep에 포함되지 않으므로 Portal/CLI로 별도 생성)
3. RAG 인덱스 생성 완료 (`scripts/setup-rag-classic.py` 실행)
4. `az login` 완료 (DefaultAzureCredential 사용)

### AI Search 생성 (아직 없는 경우)

```bash
RG="rg-aif-classic-basic-swc-dev"
az search service create \
  --name srch-$(openssl rand -hex 4) \
  --resource-group $RG \
  --location swedencentral \
  --sku basic \
  --identity-type SystemAssigned
```

### RAG 인덱스 생성

```bash
# azure-search-openai-demo 샘플 데이터 다운로드
git clone https://github.com/Azure-Samples/azure-search-openai-demo /tmp/azure-search-openai-demo

# 인덱스 생성
cd ../../scripts
python setup-rag-classic.py
```

## 실행 방법

### 방법 1: 리소스 그룹 자동 감지 (권장)

```bash
cd src/webapp
./start.sh -g rg-aif-classic-basic-swc-dev
```

### 방법 2: .env 파일 사용

```bash
cd src/webapp
cp .env.sample .env
# .env 파일을 편집하여 실제 리소스 이름 입력
./start.sh
```

### 방법 3: 수동 실행

```bash
cd src/webapp
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export AZURE_OPENAI_ENDPOINT=https://oai-xxxxxxxx.openai.azure.com
export AZURE_SEARCH_ENDPOINT=https://srch-xxxxxxxx.search.windows.net
export AZURE_SEARCH_INDEX=rag-index

python app.py
```

서버 시작 후 http://localhost:8000 에서 접속합니다.

## API 엔드포인트

| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| `/` | GET | 채팅 UI |
| `/chat` | POST | 멀티턴 RAG 채팅 |
| `/ask` | POST | 단일 질문 RAG |
| `/health` | GET | 헬스 체크 |

### /chat 요청 예시

```json
{
  "messages": [
    {"role": "user", "content": "PerksPlus 프로그램이 뭔가요?"}
  ],
  "top": 5,
  "temperature": 0.3
}
```

### /chat 응답 예시

```json
{
  "answer": "PerksPlus는 직원 복지 프로그램으로... [PerksPlus.pdf]",
  "sources": [
    {"source": "PerksPlus.pdf", "score": 0.85, "content": "..."}
  ]
}
```

## 프로젝트 구조

```
src/webapp/
├── app.py              # Quart 백엔드 (RAG API)
├── requirements.txt    # Python 의존성
├── start.sh            # 실행 스크립트
├── .env.sample         # 환경 변수 템플릿
├── templates/
│   └── index.html      # 채팅 UI
└── static/
    ├── styles.css       # 스타일시트
    └── chat.js          # 프론트엔드 JS
```
