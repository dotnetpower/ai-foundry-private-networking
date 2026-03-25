#!/usr/bin/env bash
# ================================================================
# AI Foundry RAG Chat — 실행 스크립트
# ================================================================
# 사용법:
#   ./start.sh                      # 기본 실행
#   ./start.sh --resource-group rg-aif-classic-basic-swc-dev  # 자동 감지
# ================================================================
set -euo pipefail
cd "$(dirname "$0")"

# 가상환경 생성 (최초 1회)
if [ ! -d ".venv" ]; then
    echo "🐍 가상환경 생성 중..."
    python3 -m venv .venv
fi

source .venv/bin/activate
echo "📦 의존성 설치..."
pip install -q -r requirements.txt

# --resource-group 옵션으로 자동 감지
if [[ "${1:-}" == "--resource-group" || "${1:-}" == "-g" ]]; then
    RG="${2:?리소스 그룹 이름을 입력하세요}"
    echo "📡 리소스 그룹 '${RG}'에서 리소스 자동 감지 중..."

    OAI_NAME=$(az resource list -g "$RG" --query "[?type=='Microsoft.CognitiveServices/accounts' && !contains(name,'/')].name" -o tsv | head -1)
    SEARCH_NAME=$(az resource list -g "$RG" --query "[?type=='Microsoft.Search/searchServices'].name" -o tsv | head -1)
    STORAGE_NAME=$(az resource list -g "$RG" --query "[?type=='Microsoft.Storage/storageAccounts'].name" -o tsv | head -1)

    if [ -z "$OAI_NAME" ]; then
        echo "❌ OpenAI 리소스를 찾을 수 없습니다"
        exit 1
    fi
    if [ -z "$SEARCH_NAME" ]; then
        echo "❌ AI Search 리소스를 찾을 수 없습니다"
        echo "   RAG를 위해 AI Search를 먼저 배포하세요"
        exit 1
    fi

    export AZURE_OPENAI_ENDPOINT="https://${OAI_NAME}.openai.azure.com"
    export AZURE_SEARCH_ENDPOINT="https://${SEARCH_NAME}.search.windows.net"
    export AZURE_STORAGE_ACCOUNT="${STORAGE_NAME}"
    export AZURE_OPENAI_CHAT_DEPLOYMENT="${AZURE_OPENAI_CHAT_DEPLOYMENT:-gpt-4o}"
    export AZURE_OPENAI_EMB_DEPLOYMENT="${AZURE_OPENAI_EMB_DEPLOYMENT:-text-embedding-ada-002}"
    export AZURE_SEARCH_INDEX="${AZURE_SEARCH_INDEX:-rag-index}"

    echo "  ✅ OpenAI:  ${AZURE_OPENAI_ENDPOINT}"
    echo "  ✅ Search:  ${AZURE_SEARCH_ENDPOINT}"
    echo "  ✅ Storage: ${AZURE_STORAGE_ACCOUNT}"
else
    # .env 파일에서 로드
    if [ -f .env ]; then
        echo "📂 .env 파일에서 환경 변수 로드..."
        set -a
        source .env
        set +a
    else
        echo "⚠️  .env 파일이 없습니다. .env.sample을 복사하세요:"
        echo "   cp .env.sample .env"
        echo "   또는 --resource-group 옵션을 사용하세요:"
        echo "   ./start.sh -g rg-aif-classic-basic-swc-dev"
        exit 1
    fi
fi

echo ""
echo "🚀 AI Foundry RAG Chat 서버 시작..."
echo "   http://localhost:8000"
echo ""

python app.py
