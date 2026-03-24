#!/bin/bash
# =============================================================================
# Classic Hub - Capability Host 구성 스크립트
# =============================================================================
# Classic Hub (Microsoft.MachineLearningServices/workspaces kind:Hub)에
# Standard Agent Setup용 Capability Host를 구성합니다.
#
# 사전 요구사항:
#   - Classic Hub + Project 배포 완료
#   - Storage Account, Key Vault, OpenAI 배포 완료
#   - Hub Managed VNet 프로비저닝 완료
#
# 이 스크립트가 수행하는 작업:
#   1. Cosmos DB (Serverless) 생성
#   2. AI Search (Standard + Semantic) 생성
#   3. Hub에 Connection 추가 (Cosmos DB, AI Search)
#   4. Capability Host 생성 (Project 수준)
#
# 사용법:
#   ./scripts/setup-capability-host-classic.sh --resource-group rg-aif-classic-basic-swc-dev
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

RESOURCE_GROUP=""
SUBSCRIPTION_ID=""
API_VERSION_ML="2025-01-01-preview"

while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group|-g) RESOURCE_GROUP="$2"; shift 2 ;;
    --subscription) SUBSCRIPTION_ID="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --resource-group <rg-name>"
      exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ -z "$RESOURCE_GROUP" ]; then
  echo -e "${RED}ERROR: --resource-group 필수${NC}"
  exit 1
fi

if [ -z "$SUBSCRIPTION_ID" ]; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

# =============================================================================
# 자동 감지
# =============================================================================

echo "============================================="
echo " Classic Hub - Capability Host 구성"
echo "============================================="

echo -e "${YELLOW}[1/7] 리소스 자동 감지...${NC}"

HUB_NAME=$(az resource list -g "$RESOURCE_GROUP" \
  --query "[?type=='Microsoft.MachineLearningServices/workspaces' && kind=='Hub'].name" -o tsv)
PROJECT_NAME=$(az resource list -g "$RESOURCE_GROUP" \
  --query "[?type=='Microsoft.MachineLearningServices/workspaces' && kind=='Project'].name" -o tsv)
STORAGE_NAME=$(az resource list -g "$RESOURCE_GROUP" \
  --query "[?type=='Microsoft.Storage/storageAccounts'].name" -o tsv)
OAI_NAME=$(az resource list -g "$RESOURCE_GROUP" \
  --query "[?type=='Microsoft.CognitiveServices/accounts'].name" -o tsv | head -1)
LOCATION=$(az group show -n "$RESOURCE_GROUP" --query location -o tsv)
SUFFIX=$(echo "$HUB_NAME" | sed 's/hub-//')

echo "  Hub:      $HUB_NAME"
echo "  Project:  $PROJECT_NAME"
echo "  Storage:  $STORAGE_NAME"
echo "  OpenAI:   $OAI_NAME"
echo "  Location: $LOCATION"
echo "  Suffix:   $SUFFIX"

# =============================================================================
# Cosmos DB 생성 (없으면)
# =============================================================================

COSMOS_NAME=$(az resource list -g "$RESOURCE_GROUP" \
  --query "[?type=='Microsoft.DocumentDB/databaseAccounts'].name" -o tsv)

if [ -z "$COSMOS_NAME" ]; then
  COSMOS_NAME="cosmos-${SUFFIX}"
  echo ""
  echo -e "${YELLOW}[2/7] Cosmos DB 생성: ${COSMOS_NAME}...${NC}"
  
  az cosmosdb create \
    --name "$COSMOS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --locations regionName="$LOCATION" failoverPriority=0 \
    --default-consistency-level Session \
    --enable-automatic-failover false \
    --capabilities EnableServerless \
    --kind GlobalDocumentDB \
    --public-network-access Enabled \
    -o none 2>&1
  
  # agentdb 데이터베이스 생성
  az cosmosdb sql database create \
    --account-name "$COSMOS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name agentdb -o none 2>&1
  
  echo -e "${GREEN}  ✅ Cosmos DB 생성 완료${NC}"
else
  echo ""
  echo -e "${GREEN}[2/7] Cosmos DB 이미 존재: ${COSMOS_NAME}${NC}"
fi

COSMOS_ID=$(az cosmosdb show -n "$COSMOS_NAME" -g "$RESOURCE_GROUP" --query id -o tsv)

# =============================================================================
# AI Search 생성 (없으면)
# =============================================================================

SEARCH_NAME=$(az resource list -g "$RESOURCE_GROUP" \
  --query "[?type=='Microsoft.Search/searchServices'].name" -o tsv)

if [ -z "$SEARCH_NAME" ]; then
  SEARCH_NAME="srch-${SUFFIX}"
  echo ""
  echo -e "${YELLOW}[3/7] AI Search 생성: ${SEARCH_NAME}...${NC}"
  
  az search service create \
    --name "$SEARCH_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --sku standard \
    --location "$LOCATION" \
    --semantic-search standard \
    --public-access enabled \
    --auth-options aadOrApiKey \
    --aad-auth-failure-mode http401WithBearerChallenge \
    --identity-type SystemAssigned \
    -o none 2>&1
  
  echo -e "${GREEN}  ✅ AI Search 생성 완료${NC}"
else
  echo ""
  echo -e "${GREEN}[3/7] AI Search 이미 존재: ${SEARCH_NAME}${NC}"
fi

SEARCH_ID=$(az search service show -n "$SEARCH_NAME" -g "$RESOURCE_GROUP" --query id -o tsv)

# =============================================================================
# RBAC 할당
# =============================================================================

echo ""
echo -e "${YELLOW}[4/7] RBAC 할당...${NC}"

HUB_MI=$(az resource show --ids "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${HUB_NAME}" \
  --query "identity.principalId" -o tsv 2>/dev/null)
PROJECT_MI=$(az resource show --ids "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${PROJECT_NAME}" \
  --query "identity.principalId" -o tsv 2>/dev/null)

echo "  Hub MI: $HUB_MI"
echo "  Project MI: $PROJECT_MI"

# Cosmos DB Operator
for MI in "$HUB_MI" "$PROJECT_MI"; do
  az role assignment create --assignee "$MI" \
    --role "Cosmos DB Operator" --scope "$COSMOS_ID" -o none 2>/dev/null || true
done

# Search Index Data Contributor + Search Service Contributor
for MI in "$HUB_MI" "$PROJECT_MI"; do
  az role assignment create --assignee "$MI" \
    --role "Search Index Data Contributor" --scope "$SEARCH_ID" -o none 2>/dev/null || true
  az role assignment create --assignee "$MI" \
    --role "Search Service Contributor" --scope "$SEARCH_ID" -o none 2>/dev/null || true
done

# Storage Blob Data Owner for Project MI
STORAGE_ID=$(az storage account show -g "$RESOURCE_GROUP" -n "$STORAGE_NAME" --query id -o tsv)
az role assignment create --assignee "$PROJECT_MI" \
  --role "Storage Blob Data Owner" --scope "$STORAGE_ID" -o none 2>/dev/null || true

echo -e "${GREEN}  ✅ RBAC 할당 완료${NC}"

# =============================================================================
# Hub Connections 추가 (Cosmos DB, AI Search)
# =============================================================================

echo ""
echo -e "${YELLOW}[5/7] Hub Connections 생성...${NC}"

# Storage Connection
az rest --method PUT \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${HUB_NAME}/connections/storage-connection?api-version=${API_VERSION_ML}" \
  --headers "content-type=application/json" \
  --body "{
    \"properties\": {
      \"category\": \"AzureBlobStorage\",
      \"target\": \"https://${STORAGE_NAME}.blob.core.windows.net\",
      \"authType\": \"AAD\",
      \"metadata\": {
        \"ApiType\": \"azure\",
        \"AccountName\": \"${STORAGE_NAME}\",
        \"ContainerName\": \"agents-data\",
        \"ResourceId\": \"${STORAGE_ID}\"
      }
    }
  }" -o none 2>&1 && echo "  ✅ Storage Connection" || echo "  ⚠️ Storage Connection (이미 존재할 수 있음)"

# Cosmos DB Connection
az rest --method PUT \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${HUB_NAME}/connections/cosmos-connection?api-version=${API_VERSION_ML}" \
  --headers "content-type=application/json" \
  --body "{
    \"properties\": {
      \"category\": \"CosmosDB\",
      \"target\": \"https://${COSMOS_NAME}.documents.azure.com:443/\",
      \"authType\": \"AAD\",
      \"metadata\": {
        \"ApiType\": \"azure\",
        \"AccountName\": \"${COSMOS_NAME}\",
        \"DatabaseName\": \"agentdb\",
        \"ResourceId\": \"${COSMOS_ID}\"
      }
    }
  }" -o none 2>&1 && echo "  ✅ Cosmos DB Connection" || echo "  ⚠️ Cosmos DB Connection"

# AI Search Connection
az rest --method PUT \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${HUB_NAME}/connections/search-connection?api-version=${API_VERSION_ML}" \
  --headers "content-type=application/json" \
  --body "{
    \"properties\": {
      \"category\": \"CognitiveSearch\",
      \"target\": \"https://${SEARCH_NAME}.search.windows.net\",
      \"authType\": \"AAD\",
      \"metadata\": {
        \"ApiType\": \"azure\",
        \"ResourceId\": \"${SEARCH_ID}\"
      }
    }
  }" -o none 2>&1 && echo "  ✅ AI Search Connection" || echo "  ⚠️ AI Search Connection"

# =============================================================================
# Capability Host 생성 (Project 수준)
# =============================================================================

echo ""
echo -e "${YELLOW}[6/7] Capability Host 생성 (Project: ${PROJECT_NAME})...${NC}"

CAPHOST_URL="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${PROJECT_NAME}/capabilityHosts/default?api-version=${API_VERSION_ML}"

CAPHOST_BODY="{
  \"properties\": {
    \"capabilityHostKind\": \"Agents\",
    \"storageConnections\": [\"storage-connection\"],
    \"vectorStoreConnections\": [\"search-connection\"],
    \"threadStorageConnections\": [\"cosmos-connection\"]
  }
}"

echo "  Body: $(echo "$CAPHOST_BODY" | python3 -m json.tool 2>/dev/null || echo "$CAPHOST_BODY")"

RESULT=$(az rest --method PUT --url "$CAPHOST_URL" \
  --headers "content-type=application/json" \
  --body "$CAPHOST_BODY" 2>&1)

echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"

# =============================================================================
# 프로비저닝 대기
# =============================================================================

echo ""
echo -e "${YELLOW}[7/7] Capability Host 프로비저닝 대기...${NC}"

for i in $(seq 1 30); do
  STATUS=$(az rest --method GET --url "$CAPHOST_URL" \
    --query "properties.provisioningState" -o tsv 2>/dev/null || echo "Unknown")
  
  echo "  [$i/30] 상태: ${STATUS}"
  
  if [ "$STATUS" = "Succeeded" ]; then
    echo -e "${GREEN}  ✅ Capability Host 프로비저닝 완료!${NC}"
    break
  elif [ "$STATUS" = "Failed" ]; then
    echo -e "${RED}  ❌ 프로비저닝 실패${NC}"
    az rest --method GET --url "$CAPHOST_URL" 2>/dev/null | python3 -m json.tool
    exit 1
  fi
  
  sleep 10
done

echo ""
echo "============================================="
echo -e "${GREEN} Classic Hub Capability Host 구성 완료!${NC}"
echo "============================================="
echo ""
echo "다음 단계:"
echo "  1. AI Foundry Portal에서 Project 선택"
echo "  2. Agents 메뉴에서 Agent 생성"
echo "  3. AI Search 도구 추가 + rag-index 선택"
