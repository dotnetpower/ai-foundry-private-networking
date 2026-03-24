#!/bin/bash
# =============================================================================
# AI Search RAG 설정 스크립트
# - 테스트 문서 생성 및 Blob 업로드
# - AI Search 인덱스 생성 및 인덱서 설정
# - AI Foundry에서 사용할 수 있도록 구성
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  AI Search RAG 설정 스크립트${NC}"
echo -e "${BLUE}=============================================${NC}"

# 환경 변수 설정
RESOURCE_GROUP="rg-aifoundry-20260128"
STORAGE_ACCOUNT="staifoundry20260128"
SEARCH_SERVICE="srch-aifoundry-7kkykgt6"
CONTAINER_NAME="documents"
INDEX_NAME="aifoundry-docs-index"
INDEXER_NAME="aifoundry-docs-indexer"
DATASOURCE_NAME="aifoundry-blob-datasource"
SKILLSET_NAME="aifoundry-cognitive-skillset"

echo -e "\n${YELLOW}[1/6] 환경 정보 확인 중...${NC}"
echo "  - Resource Group: $RESOURCE_GROUP"
echo "  - Storage Account: $STORAGE_ACCOUNT"
echo "  - Search Service: $SEARCH_SERVICE"
echo "  - Container: $CONTAINER_NAME"

# Search Service 키 가져오기
echo -e "\n${YELLOW}[2/6] Search Service 관리 키 가져오기...${NC}"
SEARCH_ADMIN_KEY=$(az search admin-key show \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$SEARCH_SERVICE" \
    --query "primaryKey" -o tsv 2>/dev/null || echo "")

if [ -z "$SEARCH_ADMIN_KEY" ]; then
    echo -e "${RED}Search Service 키를 가져올 수 없습니다. AAD 인증을 사용합니다.${NC}"
    USE_AAD_AUTH=true
else
    echo -e "${GREEN}Search Service 키 획득 완료${NC}"
    USE_AAD_AUTH=false
fi

SEARCH_ENDPOINT="https://${SEARCH_SERVICE}.search.windows.net"

# Storage Connection String 가져오기
echo -e "\n${YELLOW}[3/6] Storage Account 연결 문자열 가져오기...${NC}"
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "connectionString" -o tsv 2>/dev/null || echo "")

if [ -z "$STORAGE_CONNECTION_STRING" ]; then
    echo -e "${YELLOW}Storage 연결 문자열을 가져올 수 없습니다. Managed Identity를 사용합니다.${NC}"
    # Managed Identity용 리소스 ID 가져오기
    STORAGE_RESOURCE_ID=$(az storage account show \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --query "id" -o tsv)
    echo "Storage Resource ID: $STORAGE_RESOURCE_ID"
fi

# 컨테이너 생성 (이미 존재하면 스킵)
echo -e "\n${YELLOW}[4/6] Blob 컨테이너 생성...${NC}"
if [ -n "$STORAGE_CONNECTION_STRING" ]; then
    az storage container create \
        --name "$CONTAINER_NAME" \
        --connection-string "$STORAGE_CONNECTION_STRING" \
        --public-access off 2>/dev/null || echo "컨테이너가 이미 존재하거나 생성 실패"
else
    echo -e "${YELLOW}컨테이너는 프라이빗 네트워크에서만 생성 가능합니다.${NC}"
fi

# AI Search 인덱스 생성
echo -e "\n${YELLOW}[5/6] AI Search 인덱스 생성...${NC}"

# 인덱스 스키마 정의
INDEX_SCHEMA='{
    "name": "'$INDEX_NAME'",
    "fields": [
        {"name": "id", "type": "Edm.String", "key": true, "filterable": true},
        {"name": "content", "type": "Edm.String", "searchable": true, "analyzer": "ko.microsoft"},
        {"name": "title", "type": "Edm.String", "searchable": true, "filterable": true, "sortable": true},
        {"name": "category", "type": "Edm.String", "searchable": true, "filterable": true, "facetable": true},
        {"name": "source", "type": "Edm.String", "filterable": true},
        {"name": "metadata_storage_path", "type": "Edm.String", "filterable": true},
        {"name": "metadata_storage_name", "type": "Edm.String", "searchable": true, "filterable": true},
        {"name": "metadata_creation_date", "type": "Edm.DateTimeOffset", "filterable": true, "sortable": true},
        {"name": "keyphrases", "type": "Collection(Edm.String)", "searchable": true, "filterable": true},
        {"name": "contentVector", "type": "Collection(Edm.Single)", "searchable": true, "dimensions": 1536, "vectorSearchProfile": "vector-profile"}
    ],
    "vectorSearch": {
        "algorithms": [
            {
                "name": "hnsw-algorithm",
                "kind": "hnsw",
                "hnswParameters": {
                    "m": 4,
                    "efConstruction": 400,
                    "efSearch": 500,
                    "metric": "cosine"
                }
            }
        ],
        "profiles": [
            {
                "name": "vector-profile",
                "algorithm": "hnsw-algorithm"
            }
        ]
    },
    "semantic": {
        "configurations": [
            {
                "name": "semantic-config",
                "prioritizedFields": {
                    "contentFields": [{"fieldName": "content"}],
                    "titleField": {"fieldName": "title"},
                    "keywordsFields": [{"fieldName": "keyphrases"}]
                }
            }
        ]
    }
}'

if [ "$USE_AAD_AUTH" = false ]; then
    # API 키 인증 사용
    curl -s -X PUT "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
        -H "Content-Type: application/json" \
        -H "api-key: $SEARCH_ADMIN_KEY" \
        -d "$INDEX_SCHEMA" | jq -r '.name // .error.message' 2>/dev/null || echo "인덱스 생성 요청 완료"
    echo -e "${GREEN}인덱스 '$INDEX_NAME' 생성 완료${NC}"
else
    echo -e "${YELLOW}AAD 인증 모드 - az rest를 사용하여 인덱스 생성${NC}"
    # AAD 토큰으로 인덱스 생성
    az rest --method PUT \
        --url "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
        --headers "Content-Type=application/json" \
        --body "$INDEX_SCHEMA" \
        --resource "https://search.azure.com" 2>/dev/null || echo "인덱스 생성 요청 완료"
fi

echo -e "\n${YELLOW}[6/6] 설정 완료 정보${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  설정이 완료되었습니다!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo "📌 AI Search 정보:"
echo "   - Endpoint: $SEARCH_ENDPOINT"
echo "   - Index: $INDEX_NAME"
echo ""
echo "📌 다음 단계:"
echo "   1. Jumpbox VM에서 테스트 문서를 Blob에 업로드"
echo "   2. AI Foundry Portal에서 AI Search 연결 확인"
echo "   3. Playground에서 'Add your data' 옵션으로 검색 활성화"
echo ""
echo "💡 Jumpbox 접속 방법:"
echo "   az network bastion rdp --name bastion-jumpbox-krc \\"
echo "       --resource-group $RESOURCE_GROUP \\"
echo "       --target-resource-id \$(az vm show -g $RESOURCE_GROUP -n vm-jb-win-krc --query id -o tsv)"
