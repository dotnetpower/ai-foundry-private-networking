#!/bin/bash
# =============================================================================
# 05-setup-ai-search.sh - AI Search 인덱스 및 인덱서 설정
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

# SUBSCRIPTION_ID가 비어있으면 현재 구독에서 가져오기
if [ -z "$SUBSCRIPTION_ID" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)
fi

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE} [5/8] AI Search 인덱스 설정${NC}"
echo -e "${BLUE}=============================================${NC}"

# -----------------------------------------------------------------------------
# Terraform 출력에서 정보 가져오기
# -----------------------------------------------------------------------------
OUTPUTS_FILE="${SCRIPT_DIR}/../outputs.json"

if [ ! -f "$OUTPUTS_FILE" ]; then
    echo -e "${RED}Error: outputs.json 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi

AI_SEARCH_NAME=$(jq -r '.ai_search_name.value' "$OUTPUTS_FILE")
STORAGE_ACCOUNT=$(jq -r '.storage_account_name.value' "$OUTPUTS_FILE")

if [ -z "$AI_SEARCH_NAME" ] || [ "$AI_SEARCH_NAME" == "null" ]; then
    echo -e "${RED}Error: AI Search 이름을 찾을 수 없습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}AI Search: $AI_SEARCH_NAME${NC}"
echo -e "${GREEN}Storage: $STORAGE_ACCOUNT${NC}"

# AI Search 엔드포인트
SEARCH_ENDPOINT="https://${AI_SEARCH_NAME}.search.windows.net"

# Azure AD 토큰 가져오기
echo -e "\n${YELLOW}Azure AD 토큰 가져오는 중...${NC}"
ACCESS_TOKEN=$(az account get-access-token --resource "https://search.azure.com" --query accessToken -o tsv)

# Storage 연결 문자열 (Managed Identity 사용)
STORAGE_CONNECTION="ResourceId=/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT;"

# -----------------------------------------------------------------------------
# 데이터 소스 생성
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}데이터 소스 생성 중...${NC}"

DATASOURCE_NAME="datasource-blob"

cat > /tmp/datasource.json << EOF
{
    "name": "$DATASOURCE_NAME",
    "type": "azureblob",
    "credentials": {
        "connectionString": "$STORAGE_CONNECTION"
    },
    "container": {
        "name": "$TEST_DATA_CONTAINER"
    }
}
EOF

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
    "$SEARCH_ENDPOINT/datasources/$DATASOURCE_NAME?api-version=2024-07-01" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d @/tmp/datasource.json)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo -e "${GREEN}✓ 데이터 소스 생성됨: $DATASOURCE_NAME${NC}"
else
    echo -e "${YELLOW}데이터 소스 응답: $RESPONSE${NC}"
fi

# -----------------------------------------------------------------------------
# 인덱스 생성
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}인덱스 생성 중...${NC}"

cat > /tmp/index.json << EOF
{
    "name": "$AI_SEARCH_INDEX_NAME",
    "fields": [
        {"name": "id", "type": "Edm.String", "key": true, "searchable": false},
        {"name": "content", "type": "Edm.String", "searchable": true, "analyzer": "standard.lucene"},
        {"name": "metadata_storage_path", "type": "Edm.String", "searchable": false, "filterable": true},
        {"name": "metadata_storage_name", "type": "Edm.String", "searchable": true, "filterable": true},
        {"name": "metadata_content_type", "type": "Edm.String", "searchable": false, "filterable": true},
        {"name": "metadata_storage_size", "type": "Edm.Int64", "searchable": false, "filterable": true}
    ],
    "semantic": {
        "configurations": [
            {
                "name": "semantic-config",
                "prioritizedFields": {
                    "contentFields": [
                        {"fieldName": "content"}
                    ],
                    "titleField": {"fieldName": "metadata_storage_name"}
                }
            }
        ]
    }
}
EOF

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
    "$SEARCH_ENDPOINT/indexes/$AI_SEARCH_INDEX_NAME?api-version=2024-07-01" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d @/tmp/index.json)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo -e "${GREEN}✓ 인덱스 생성됨: $AI_SEARCH_INDEX_NAME${NC}"
else
    echo -e "${YELLOW}인덱스 응답: $RESPONSE${NC}"
fi

# -----------------------------------------------------------------------------
# 인덱서 생성
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}인덱서 생성 중...${NC}"

INDEXER_NAME="indexer-blob"

cat > /tmp/indexer.json << EOF
{
    "name": "$INDEXER_NAME",
    "dataSourceName": "$DATASOURCE_NAME",
    "targetIndexName": "$AI_SEARCH_INDEX_NAME",
    "parameters": {
        "configuration": {
            "parsingMode": "default",
            "dataToExtract": "contentAndMetadata"
        }
    },
    "fieldMappings": [
        {"sourceFieldName": "metadata_storage_path", "targetFieldName": "id", "mappingFunction": {"name": "base64Encode"}},
        {"sourceFieldName": "metadata_storage_path", "targetFieldName": "metadata_storage_path"},
        {"sourceFieldName": "metadata_storage_name", "targetFieldName": "metadata_storage_name"},
        {"sourceFieldName": "metadata_content_type", "targetFieldName": "metadata_content_type"},
        {"sourceFieldName": "metadata_storage_size", "targetFieldName": "metadata_storage_size"}
    ]
}
EOF

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
    "$SEARCH_ENDPOINT/indexers/$INDEXER_NAME?api-version=2024-07-01" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d @/tmp/indexer.json)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo -e "${GREEN}✓ 인덱서 생성됨: $INDEXER_NAME${NC}"
else
    echo -e "${YELLOW}인덱서 응답: $RESPONSE${NC}"
fi

# -----------------------------------------------------------------------------
# 인덱서 실행
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}인덱서 실행 중...${NC}"

curl -s -X POST \
    "$SEARCH_ENDPOINT/indexers/$INDEXER_NAME/run?api-version=2024-07-01" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json"

echo -e "${GREEN}✓ 인덱서 실행 요청됨${NC}"

# -----------------------------------------------------------------------------
# 인덱싱 완료 대기
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}인덱싱 완료 대기 중...${NC}"

for i in {1..30}; do
    sleep 10
    
    STATUS_RESPONSE=$(curl -s \
        "$SEARCH_ENDPOINT/indexers/$INDEXER_NAME/status?api-version=2024-07-01" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.lastResult.status // "unknown"')
    DOCS_PROCESSED=$(echo "$STATUS_RESPONSE" | jq -r '.lastResult.itemsProcessed // 0')
    DOCS_FAILED=$(echo "$STATUS_RESPONSE" | jq -r '.lastResult.itemsFailed // 0')
    
    echo "  [$i/30] 상태: $STATUS, 처리됨: $DOCS_PROCESSED, 실패: $DOCS_FAILED"
    
    if [ "$STATUS" == "success" ]; then
        echo -e "${GREEN}✓ 인덱싱 완료!${NC}"
        break
    elif [ "$STATUS" == "transientFailure" ] || [ "$STATUS" == "persistentFailure" ]; then
        echo -e "${RED}✗ 인덱싱 실패${NC}"
        echo "$STATUS_RESPONSE" | jq '.lastResult.errors'
        break
    fi
done

# -----------------------------------------------------------------------------
# 인덱스 문서 수 확인
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}인덱스 정보:${NC}"

DOC_COUNT_RESPONSE=$(curl -s \
    "$SEARCH_ENDPOINT/indexes/$AI_SEARCH_INDEX_NAME/docs/\$count?api-version=2024-07-01" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

echo "  인덱스된 문서 수: $DOC_COUNT_RESPONSE"

# 임시 파일 정리
rm -f /tmp/datasource.json /tmp/index.json /tmp/indexer.json

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN} [5/8] AI Search 인덱스 설정 완료${NC}"
echo -e "${GREEN}=============================================${NC}"
