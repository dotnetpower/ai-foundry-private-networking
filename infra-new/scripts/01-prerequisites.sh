#!/bin/bash
# =============================================================================
# 01-prerequisites.sh - 사전 요구사항 확인 및 설정
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
echo -e "${BLUE} [1/8] 사전 요구사항 확인${NC}"
echo -e "${BLUE}=============================================${NC}"

# -----------------------------------------------------------------------------
# Azure CLI 로그인 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}Azure CLI 로그인 확인 중...${NC}"

if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Azure CLI 로그인이 필요합니다.${NC}"
    echo "az login 명령을 실행하세요."
    exit 1
fi

CURRENT_SUB=$(az account show --query id -o tsv)
CURRENT_SUB_NAME=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ 로그인됨: $CURRENT_SUB_NAME${NC}"

# 구독 설정
if [ -n "$SUBSCRIPTION_ID" ] && [ "$SUBSCRIPTION_ID" != "$CURRENT_SUB" ]; then
    echo -e "${YELLOW}구독 변경 중: $SUBSCRIPTION_ID${NC}"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

echo -e "${GREEN}✓ 구독: $(az account show --query name -o tsv)${NC}"

# -----------------------------------------------------------------------------
# 필수 도구 확인
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}필수 도구 확인 중...${NC}"

# Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform이 설치되어 있지 않습니다.${NC}"
    exit 1
fi
TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo -e "${GREEN}✓ Terraform: $TERRAFORM_VERSION${NC}"

# jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq가 설치되어 있지 않습니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ jq: $(jq --version)${NC}"

# -----------------------------------------------------------------------------
# Resource Provider 등록
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}Resource Provider 등록 확인 중...${NC}"

PROVIDERS=(
    "Microsoft.CognitiveServices"
    "Microsoft.Storage"
    "Microsoft.Search"
    "Microsoft.DocumentDB"
    "Microsoft.Network"
    "Microsoft.App"
    "Microsoft.ContainerService"
)

for provider in "${PROVIDERS[@]}"; do
    status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
    if [ "$status" != "Registered" ]; then
        echo -e "${YELLOW}  → $provider 등록 중...${NC}"
        az provider register --namespace "$provider"
    else
        echo -e "${GREEN}  ✓ $provider${NC}"
    fi
done

# 등록 완료 대기
echo -e "\n${YELLOW}Resource Provider 등록 완료 대기 중...${NC}"
for provider in "${PROVIDERS[@]}"; do
    while true; do
        status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
        if [ "$status" == "Registered" ]; then
            break
        fi
        echo "  $provider: $status"
        sleep 5
    done
done
echo -e "${GREEN}✓ 모든 Resource Provider 등록 완료${NC}"

# -----------------------------------------------------------------------------
# 리소스 그룹 생성
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}리소스 그룹 확인 중...${NC}"

if az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    echo -e "${GREEN}✓ 리소스 그룹 존재: $RESOURCE_GROUP_NAME${NC}"
else
    echo -e "${YELLOW}리소스 그룹 생성 중: $RESOURCE_GROUP_NAME${NC}"
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" \
        --tags Environment="$TAG_ENVIRONMENT" Project="$TAG_PROJECT" ManagedBy="$TAG_MANAGED_BY"
    echo -e "${GREEN}✓ 리소스 그룹 생성됨${NC}"
fi

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN} [1/8] 사전 요구사항 확인 완료${NC}"
echo -e "${GREEN}=============================================${NC}"
