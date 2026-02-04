#!/bin/bash
# =============================================================================
# Capability Host 수동 생성 스크립트
# Terraform 배포 실패 시 수동으로 실행
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 -a <account-name> -p <project-name> -g <resource-group> \\"
    echo "          -c <caphost-name> --cosmos <cosmos-connection> \\"
    echo "          --storage <storage-connection> --search <search-connection>"
    echo ""
    echo "Options:"
    echo "  -a, --account     AI Services Account 이름"
    echo "  -p, --project     Project 이름"
    echo "  -g, --rg          Resource Group 이름"
    echo "  -c, --caphost     Capability Host 이름 (기본값: caphostproj)"
    echo "  --cosmos          CosmosDB Connection 이름"
    echo "  --storage         Storage Connection 이름"
    echo "  --search          AI Search Connection 이름"
    exit 1
}

CAPHOST_NAME="caphostproj"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--account) ACCOUNT_NAME="$2"; shift 2 ;;
        -p|--project) PROJECT_NAME="$2"; shift 2 ;;
        -g|--rg) RESOURCE_GROUP="$2"; shift 2 ;;
        -c|--caphost) CAPHOST_NAME="$2"; shift 2 ;;
        --cosmos) COSMOS_CONNECTION="$2"; shift 2 ;;
        --storage) STORAGE_CONNECTION="$2"; shift 2 ;;
        --search) SEARCH_CONNECTION="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# 필수 매개변수 확인
if [ -z "$ACCOUNT_NAME" ] || [ -z "$PROJECT_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}Error: 필수 매개변수가 누락되었습니다.${NC}"
    usage
fi

if [ -z "$COSMOS_CONNECTION" ] || [ -z "$STORAGE_CONNECTION" ] || [ -z "$SEARCH_CONNECTION" ]; then
    echo -e "${RED}Error: Connection 이름이 필요합니다.${NC}"
    usage
fi

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE} Capability Host 수동 생성${NC}"
echo -e "${BLUE}=============================================${NC}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo -e "${YELLOW}생성 정보:${NC}"
echo "  Account: $ACCOUNT_NAME"
echo "  Project: $PROJECT_NAME"
echo "  CapHost: $CAPHOST_NAME"
echo "  CosmosDB Connection: $COSMOS_CONNECTION"
echo "  Storage Connection: $STORAGE_CONNECTION"
echo "  Search Connection: $SEARCH_CONNECTION"

# Capability Host 리소스 ID
CAPHOST_URL="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}/projects/${PROJECT_NAME}/capabilityHosts/${CAPHOST_NAME}?api-version=2025-04-01-preview"

# Request Body
REQUEST_BODY=$(cat <<EOF
{
    "properties": {
        "capabilityHostKind": "Agents",
        "vectorStoreConnections": ["${SEARCH_CONNECTION}"],
        "storageConnections": ["${STORAGE_CONNECTION}"],
        "threadStorageConnections": ["${COSMOS_CONNECTION}"]
    }
}
EOF
)

echo -e "\n${YELLOW}Capability Host 생성 요청 중...${NC}"

RESPONSE=$(az rest --method PUT \
    --url "$CAPHOST_URL" \
    --body "$REQUEST_BODY" \
    --headers "Content-Type=application/json" 2>&1)

echo -e "\n${BLUE}응답:${NC}"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"

# 상태 확인
echo -e "\n${YELLOW}생성 상태 확인 중... (최대 20분 소요)${NC}"

for i in {1..40}; do
    sleep 30
    
    STATUS=$(az rest --method GET \
        --url "$CAPHOST_URL" \
        --query "properties.provisioningState" -o tsv 2>/dev/null || echo "Unknown")
    
    echo "  [$i/40] 상태: $STATUS"
    
    if [ "$STATUS" == "Succeeded" ]; then
        echo -e "\n${GREEN}✓ Capability Host가 성공적으로 생성되었습니다!${NC}"
        exit 0
    elif [ "$STATUS" == "Failed" ]; then
        echo -e "\n${RED}✗ Capability Host 생성 실패${NC}"
        
        # 실패 원인 조회
        az rest --method GET --url "$CAPHOST_URL" | jq '.properties'
        exit 1
    fi
done

echo -e "\n${YELLOW}생성이 아직 진행 중입니다. 나중에 확인하세요.${NC}"
