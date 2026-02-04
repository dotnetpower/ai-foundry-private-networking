#!/bin/bash
# =============================================================================
# Capability Host 삭제 스크립트
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 -a <account-name> -p <project-name> -g <resource-group> [-c <caphost-name>]"
    echo ""
    echo "Options:"
    echo "  -a    AI Services Account 이름"
    echo "  -p    Project 이름"
    echo "  -g    Resource Group 이름"
    echo "  -c    Capability Host 이름 (기본값: caphostproj)"
    exit 1
}

CAPHOST_NAME="caphostproj"

while getopts "a:p:g:c:h" opt; do
    case $opt in
        a) ACCOUNT_NAME="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        g) RESOURCE_GROUP="$OPTARG" ;;
        c) CAPHOST_NAME="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$ACCOUNT_NAME" ] || [ -z "$PROJECT_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}Error: 필수 매개변수가 누락되었습니다.${NC}"
    usage
fi

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE} Capability Host 삭제${NC}"
echo -e "${BLUE}=============================================${NC}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Capability Host 리소스 ID 구성
CAPHOST_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}/projects/${PROJECT_NAME}/capabilityHosts/${CAPHOST_NAME}"

echo -e "${YELLOW}삭제할 Capability Host:${NC}"
echo "  Account: $ACCOUNT_NAME"
echo "  Project: $PROJECT_NAME"
echo "  CapHost: $CAPHOST_NAME"
echo "  Resource ID: $CAPHOST_ID"

read -p "정말 삭제하시겠습니까? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${YELLOW}삭제가 취소되었습니다.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}Capability Host 삭제 중...${NC}"

az rest --method DELETE \
    --url "https://management.azure.com${CAPHOST_ID}?api-version=2025-04-01-preview"

echo -e "\n${GREEN}✓ Capability Host 삭제 요청 완료${NC}"
echo -e "${YELLOW}참고: 완전 삭제까지 최대 20분 소요될 수 있습니다.${NC}"

# 상태 확인
echo -e "\n${BLUE}삭제 상태 확인 중...${NC}"
for i in {1..10}; do
    sleep 30
    
    status=$(az rest --method GET \
        --url "https://management.azure.com${CAPHOST_ID}?api-version=2025-04-01-preview" \
        --query "properties.provisioningState" -o tsv 2>/dev/null || echo "Deleted")
    
    if [ "$status" == "Deleted" ] || [ -z "$status" ]; then
        echo -e "${GREEN}✓ Capability Host가 삭제되었습니다.${NC}"
        exit 0
    fi
    
    echo "  상태: $status (${i}/10)"
done

echo -e "${YELLOW}삭제가 진행 중입니다. 나중에 다시 확인하세요.${NC}"
