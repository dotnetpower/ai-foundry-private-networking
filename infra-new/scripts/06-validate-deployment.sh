#!/bin/bash
# =============================================================================
# 06-validate-deployment.sh - 배포 검증 및 결과 출력
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
echo -e "${BLUE} [6/8] 배포 검증${NC}"
echo -e "${BLUE}=============================================${NC}"

ERRORS=0

# -----------------------------------------------------------------------------
# Terraform 출력 로드
# -----------------------------------------------------------------------------
OUTPUTS_FILE="${SCRIPT_DIR}/../outputs.json"

if [ ! -f "$OUTPUTS_FILE" ]; then
    echo -e "${RED}Error: outputs.json 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi

AI_ACCOUNT_NAME=$(jq -r '.ai_account_name.value' "$OUTPUTS_FILE")
PROJECT_NAME=$(jq -r '.project_name.value' "$OUTPUTS_FILE")
STORAGE_ACCOUNT=$(jq -r '.storage_account_name.value' "$OUTPUTS_FILE")
COSMOS_DB_NAME=$(jq -r '.cosmos_db_name.value' "$OUTPUTS_FILE")
AI_SEARCH_NAME=$(jq -r '.ai_search_name.value' "$OUTPUTS_FILE")
CAPABILITY_HOST_NAME=$(jq -r '.capability_host_name.value' "$OUTPUTS_FILE")

# -----------------------------------------------------------------------------
# AI Services Account 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}AI Services Account 확인 중...${NC}"

ACCOUNT_STATUS=$(az cognitiveservices account show \
    --name "$AI_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "properties.provisioningState" -o tsv 2>/dev/null || echo "NotFound")

if [ "$ACCOUNT_STATUS" == "Succeeded" ]; then
    echo -e "${GREEN}✓ AI Services Account: $AI_ACCOUNT_NAME (Succeeded)${NC}"
else
    echo -e "${RED}✗ AI Services Account: $ACCOUNT_STATUS${NC}"
    ((ERRORS++))
fi

# -----------------------------------------------------------------------------
# AI Project 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}AI Project 확인 중...${NC}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
PROJECT_URL="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.CognitiveServices/accounts/${AI_ACCOUNT_NAME}/projects/${PROJECT_NAME}?api-version=2025-04-01-preview"

PROJECT_STATUS=$(az rest --method GET --url "$PROJECT_URL" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "NotFound")

if [ "$PROJECT_STATUS" == "Succeeded" ]; then
    echo -e "${GREEN}✓ AI Project: $PROJECT_NAME (Succeeded)${NC}"
else
    echo -e "${RED}✗ AI Project: $PROJECT_STATUS${NC}"
    ((ERRORS++))
fi

# -----------------------------------------------------------------------------
# Capability Host 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}Capability Host 확인 중...${NC}"

CAPHOST_URL="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.CognitiveServices/accounts/${AI_ACCOUNT_NAME}/projects/${PROJECT_NAME}/capabilityHosts/${CAPABILITY_HOST_NAME}?api-version=2025-04-01-preview"

CAPHOST_STATUS=$(az rest --method GET --url "$CAPHOST_URL" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "NotFound")

if [ "$CAPHOST_STATUS" == "Succeeded" ]; then
    echo -e "${GREEN}✓ Capability Host: $CAPABILITY_HOST_NAME (Succeeded)${NC}"
else
    echo -e "${RED}✗ Capability Host: $CAPHOST_STATUS${NC}"
    ((ERRORS++))
fi

# -----------------------------------------------------------------------------
# 의존 리소스 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}의존 리소스 확인 중...${NC}"

# Storage Account
STORAGE_STATUS=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP_NAME" \
    --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
if [ "$STORAGE_STATUS" == "Succeeded" ]; then
    echo -e "${GREEN}✓ Storage Account: $STORAGE_ACCOUNT${NC}"
else
    echo -e "${RED}✗ Storage Account: $STORAGE_STATUS${NC}"
    ((ERRORS++))
fi

# CosmosDB
COSMOS_STATUS=$(az cosmosdb show --name "$COSMOS_DB_NAME" --resource-group "$RESOURCE_GROUP_NAME" \
    --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
if [ "$COSMOS_STATUS" == "Succeeded" ]; then
    echo -e "${GREEN}✓ CosmosDB: $COSMOS_DB_NAME${NC}"
else
    echo -e "${RED}✗ CosmosDB: $COSMOS_STATUS${NC}"
    ((ERRORS++))
fi

# AI Search
SEARCH_STATUS=$(az search service show --name "$AI_SEARCH_NAME" --resource-group "$RESOURCE_GROUP_NAME" \
    --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
if [ "$SEARCH_STATUS" == "Succeeded" ]; then
    echo -e "${GREEN}✓ AI Search: $AI_SEARCH_NAME${NC}"
else
    echo -e "${RED}✗ AI Search: $SEARCH_STATUS${NC}"
    ((ERRORS++))
fi

# -----------------------------------------------------------------------------
# Private Endpoints 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}Private Endpoints 확인 중...${NC}"

PE_LIST=$(az network private-endpoint list --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[].{name:name, status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
    -o table 2>/dev/null)

echo "$PE_LIST"

PE_APPROVED=$(az network private-endpoint list --resource-group "$RESOURCE_GROUP_NAME" \
    --query "length([?privateLinkServiceConnections[0].privateLinkServiceConnectionState.status=='Approved'])" \
    -o tsv 2>/dev/null || echo "0")

if [ "$PE_APPROVED" -ge 4 ]; then
    echo -e "${GREEN}✓ Private Endpoints 승인됨: $PE_APPROVED개${NC}"
else
    echo -e "${YELLOW}⚠ Private Endpoints: $PE_APPROVED개${NC}"
fi

# -----------------------------------------------------------------------------
# AI Search 인덱스 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}AI Search 인덱스 확인 중...${NC}"

SEARCH_ENDPOINT="https://${AI_SEARCH_NAME}.search.windows.net"
ACCESS_TOKEN=$(az account get-access-token --resource "https://search.azure.com" --query accessToken -o tsv 2>/dev/null || echo "")

if [ -n "$ACCESS_TOKEN" ]; then
    DOC_COUNT=$(curl -s \
        "$SEARCH_ENDPOINT/indexes/$AI_SEARCH_INDEX_NAME/docs/\$count?api-version=2024-07-01" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null || echo "0")
    
    if [ "$DOC_COUNT" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✓ 인덱스 문서 수: $DOC_COUNT${NC}"
    else
        echo -e "${YELLOW}⚠ 인덱스 문서 수: $DOC_COUNT${NC}"
    fi
fi

# -----------------------------------------------------------------------------
# 결과 요약
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}=============================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN} ✓ 모든 검증 통과!${NC}"
else
    echo -e "${RED} ✗ $ERRORS개의 문제 발견${NC}"
fi
echo -e "${BLUE}=============================================${NC}"

# -----------------------------------------------------------------------------
# 접속 정보 출력
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}========== 접속 정보 ==========${NC}"
echo ""
echo -e "${YELLOW}AI Foundry Portal:${NC}"
echo "  URL: https://ai.azure.com"
echo "  Project: $PROJECT_NAME"
echo ""
echo -e "${YELLOW}리소스 그룹:${NC}"
echo "  이름: $RESOURCE_GROUP_NAME"
echo "  URL: https://portal.azure.com/#@/resource/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}"
echo ""
echo -e "${YELLOW}주요 리소스:${NC}"
echo "  AI Services: $AI_ACCOUNT_NAME"
echo "  AI Project: $PROJECT_NAME"
echo "  Storage: $STORAGE_ACCOUNT"
echo "  CosmosDB: $COSMOS_DB_NAME"
echo "  AI Search: $AI_SEARCH_NAME"
echo "  AI Search Index: $AI_SEARCH_INDEX_NAME"
echo ""

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN} [6/8] 배포 검증 완료${NC}"
echo -e "${GREEN}=============================================${NC}"

exit $ERRORS
