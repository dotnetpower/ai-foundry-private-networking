#!/bin/bash
# =============================================================================
# Standard Agent Setup - Capability Host 구성 스크립트
# =============================================================================
# Bicep 배포 후 Capability Host를 CLI (az rest)로 구성합니다.
# Bicep API(2025-04-01-preview)에서 virtualNetworkSubnetResourceId가 미지원이므로
# 이 스크립트로 Capability Host를 자동 설정합니다.
#
# 사용법:
#   ./scripts/setup-capability-host.sh \
#     --subscription <subscription-id> \
#     --resource-group <rg-name> \
#     --account-name <foundry-account-name> \
#     --project-name <foundry-project-name> \
#     --agent-subnet-id <full-subnet-resource-id>
# =============================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 기본값
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
ACCOUNT_NAME=""
PROJECT_NAME=""
AGENT_SUBNET_ID=""
API_VERSION="2025-04-01-preview"

# 인자 파싱
while [[ $# -gt 0 ]]; do
  case $1 in
    --subscription) SUBSCRIPTION_ID="$2"; shift 2 ;;
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --account-name) ACCOUNT_NAME="$2"; shift 2 ;;
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --agent-subnet-id) AGENT_SUBNET_ID="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --subscription <id> --resource-group <rg> --account-name <name> --project-name <name> --agent-subnet-id <id>"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# =============================================================================
# 자동 감지 (인자 미입력 시)
# =============================================================================

if [ -z "$SUBSCRIPTION_ID" ]; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
  echo -e "${YELLOW}구독 자동 감지: ${SUBSCRIPTION_ID}${NC}"
fi

if [ -z "$RESOURCE_GROUP" ]; then
  echo -e "${RED}ERROR: --resource-group 필수${NC}"
  exit 1
fi

if [ -z "$ACCOUNT_NAME" ]; then
  ACCOUNT_NAME=$(az cognitiveservices account list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
  echo -e "${YELLOW}Foundry Account 자동 감지: ${ACCOUNT_NAME}${NC}"
fi

if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(az rest --method GET \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}/projects?api-version=${API_VERSION}" \
    --query "value[0].name" -o tsv 2>/dev/null)
  echo -e "${YELLOW}Foundry Project 자동 감지: ${PROJECT_NAME}${NC}"
fi

if [ -z "$AGENT_SUBNET_ID" ]; then
  # VNet에서 agent subnet 자동 감지
  VNET_NAME=$(az network vnet list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null)
  if [ -n "$VNET_NAME" ]; then
    AGENT_SUBNET_ID=$(az network vnet subnet show -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" -n "snet-agent" --query id -o tsv 2>/dev/null || \
      az network vnet subnet list -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --query "[?contains(name,'agent')].id" -o tsv 2>/dev/null | head -1)
  fi
  if [ -z "$AGENT_SUBNET_ID" ]; then
    echo -e "${RED}ERROR: Agent subnet을 자동 감지할 수 없습니다. --agent-subnet-id를 지정하세요.${NC}"
    exit 1
  fi
  echo -e "${YELLOW}Agent Subnet 자동 감지: ${AGENT_SUBNET_ID}${NC}"
fi

# =============================================================================
# 사전 확인
# =============================================================================

echo ""
echo "=== Standard Agent Setup - Capability Host 구성 ==="
echo "구독:           ${SUBSCRIPTION_ID}"
echo "리소스 그룹:     ${RESOURCE_GROUP}"
echo "Foundry Account: ${ACCOUNT_NAME}"
echo "Foundry Project: ${PROJECT_NAME}"
echo "Agent Subnet:    ${AGENT_SUBNET_ID}"
echo ""

# Connection 이름 확인
echo -e "${YELLOW}[1/4] Connection 목록 확인...${NC}"
CONNECTIONS=$(az rest --method GET \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}/projects/${PROJECT_NAME}/connections?api-version=${API_VERSION}" \
  --query "value[].name" -o tsv 2>/dev/null)

STORAGE_CONN=""
COSMOS_CONN=""
SEARCH_CONN=""

while IFS= read -r conn; do
  if [[ "$conn" == *storage* ]]; then STORAGE_CONN="$conn"; fi
  if [[ "$conn" == *cosmos* ]]; then COSMOS_CONN="$conn"; fi
  if [[ "$conn" == *search* ]]; then SEARCH_CONN="$conn"; fi
done <<< "$CONNECTIONS"

echo "  Storage Connection: ${STORAGE_CONN:-'not found'}"
echo "  Cosmos Connection:  ${COSMOS_CONN:-'not found'}"
echo "  Search Connection:  ${SEARCH_CONN:-'not found'}"

# =============================================================================
# Capability Host 생성 (Project 수준)
# =============================================================================

echo ""
echo -e "${YELLOW}[2/4] Capability Host 생성 (Project 수준)...${NC}"

CAPHOST_URL="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}/projects/${PROJECT_NAME}/capabilityHosts/default?api-version=${API_VERSION}"

# Capability Host body 구성
CAPHOST_BODY=$(cat <<EOF
{
  "properties": {
    "capabilityHostKind": "Agents",
    "virtualNetworkSubnetResourceId": "${AGENT_SUBNET_ID}"
EOF
)

# Storage Connection 추가
if [ -n "$STORAGE_CONN" ]; then
  CAPHOST_BODY="${CAPHOST_BODY}, \"storageConnections\": [\"${STORAGE_CONN}\"]"
fi

# Search Connection 추가
if [ -n "$SEARCH_CONN" ]; then
  CAPHOST_BODY="${CAPHOST_BODY}, \"vectorStoreConnections\": [\"${SEARCH_CONN}\"]"
fi

# Cosmos Connection 추가
if [ -n "$COSMOS_CONN" ]; then
  CAPHOST_BODY="${CAPHOST_BODY}, \"threadStorageConnections\": [\"${COSMOS_CONN}\"]"
fi

CAPHOST_BODY="${CAPHOST_BODY} } }"

echo "  요청 Body:"
echo "$CAPHOST_BODY" | python3 -m json.tool 2>/dev/null || echo "$CAPHOST_BODY"
echo ""

az rest --method PUT \
  --url "$CAPHOST_URL" \
  --headers "content-type=application/json" \
  --body "$CAPHOST_BODY"

echo -e "${GREEN}  Capability Host 생성 요청 완료${NC}"

# =============================================================================
# 상태 확인 (폴링)
# =============================================================================

echo ""
echo -e "${YELLOW}[3/4] Capability Host 프로비저닝 대기...${NC}"

MAX_RETRIES=30
RETRY_INTERVAL=10

for i in $(seq 1 $MAX_RETRIES); do
  STATUS=$(az rest --method GET --url "$CAPHOST_URL" \
    --query "properties.provisioningState" -o tsv 2>/dev/null || echo "Unknown")

  echo "  [$i/$MAX_RETRIES] 상태: ${STATUS}"

  if [ "$STATUS" = "Succeeded" ]; then
    echo -e "${GREEN}  Capability Host 프로비저닝 완료${NC}"
    break
  elif [ "$STATUS" = "Failed" ]; then
    echo -e "${RED}  Capability Host 프로비저닝 실패${NC}"
    az rest --method GET --url "$CAPHOST_URL" 2>/dev/null | python3 -m json.tool
    exit 1
  fi

  sleep $RETRY_INTERVAL
done

# =============================================================================
# 결과 확인
# =============================================================================

echo ""
echo -e "${YELLOW}[4/4] 최종 상태 확인...${NC}"

az rest --method GET --url "$CAPHOST_URL" 2>/dev/null | python3 -m json.tool

echo ""
echo -e "${GREEN}=== 완료 ===${NC}"
echo "Azure Portal에서 Agent 테스트:"
echo "  AI Foundry > ${PROJECT_NAME} > Agents > + New Agent"
