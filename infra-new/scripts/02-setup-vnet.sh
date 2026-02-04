#!/bin/bash
# =============================================================================
# 02-setup-vnet.sh - VNet 구성 (기존 사용 또는 신규 생성)
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
echo -e "${BLUE} [2/8] VNet 구성${NC}"
echo -e "${BLUE}=============================================${NC}"

# -----------------------------------------------------------------------------
# VNet 확인/생성
# -----------------------------------------------------------------------------
if [ -n "$EXISTING_VNET_NAME" ]; then
    # 기존 VNet 사용
    echo -e "\n${YELLOW}기존 VNet 확인 중: $EXISTING_VNET_NAME${NC}"
    
    VNET_RG="${EXISTING_VNET_RG:-$RESOURCE_GROUP_NAME}"
    
    if ! az network vnet show --name "$EXISTING_VNET_NAME" --resource-group "$VNET_RG" &> /dev/null; then
        echo -e "${RED}Error: VNet을 찾을 수 없습니다: $EXISTING_VNET_NAME${NC}"
        exit 1
    fi
    
    VNET_NAME="$EXISTING_VNET_NAME"
    echo -e "${GREEN}✓ 기존 VNet 사용: $VNET_NAME${NC}"
    
    # 주소 공간 확인
    VNET_PREFIXES=$(az network vnet show --name "$VNET_NAME" --resource-group "$VNET_RG" \
        --query "addressSpace.addressPrefixes" -o tsv)
    echo -e "  주소 공간: $VNET_PREFIXES"
else
    # 새 VNet 생성
    echo -e "\n${YELLOW}새 VNet 생성 중: $NEW_VNET_NAME${NC}"
    
    VNET_NAME="$NEW_VNET_NAME"
    VNET_RG="$RESOURCE_GROUP_NAME"
    
    if az network vnet show --name "$VNET_NAME" --resource-group "$VNET_RG" &> /dev/null; then
        echo -e "${GREEN}✓ VNet 이미 존재: $VNET_NAME${NC}"
    else
        az network vnet create \
            --name "$VNET_NAME" \
            --resource-group "$VNET_RG" \
            --location "$LOCATION" \
            --address-prefix "$NEW_VNET_PREFIX" \
            --tags Environment="$TAG_ENVIRONMENT" Project="$TAG_PROJECT"
        echo -e "${GREEN}✓ VNet 생성됨: $VNET_NAME${NC}"
    fi
fi

# -----------------------------------------------------------------------------
# Agent 서브넷 구성 (Microsoft.App/environments 위임)
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}Agent 서브넷 구성 중: $AGENT_SUBNET_NAME${NC}"

if az network vnet subnet show --name "$AGENT_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" &> /dev/null; then
    echo -e "${GREEN}✓ Agent 서브넷 이미 존재${NC}"
    
    # 위임 확인
    DELEGATION=$(az network vnet subnet show --name "$AGENT_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" \
        --query "delegations[?serviceName=='Microsoft.App/environments'].serviceName" -o tsv)
    
    if [ -z "$DELEGATION" ]; then
        echo -e "${YELLOW}  → Microsoft.App/environments 위임 추가 중...${NC}"
        az network vnet subnet update \
            --name "$AGENT_SUBNET_NAME" \
            --vnet-name "$VNET_NAME" \
            --resource-group "$VNET_RG" \
            --delegations "Microsoft.App/environments"
        echo -e "${GREEN}  ✓ 위임 추가됨${NC}"
    else
        echo -e "${GREEN}  ✓ Microsoft.App/environments 위임 확인됨${NC}"
    fi
else
    az network vnet subnet create \
        --name "$AGENT_SUBNET_NAME" \
        --vnet-name "$VNET_NAME" \
        --resource-group "$VNET_RG" \
        --address-prefix "$AGENT_SUBNET_PREFIX" \
        --delegations "Microsoft.App/environments" \
        --default-outbound false
    echo -e "${GREEN}✓ Agent 서브넷 생성됨 (Microsoft.App/environments 위임)${NC}"
fi

# -----------------------------------------------------------------------------
# Private Endpoint 서브넷 구성
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}PE 서브넷 구성 중: $PE_SUBNET_NAME${NC}"

if az network vnet subnet show --name "$PE_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" &> /dev/null; then
    echo -e "${GREEN}✓ PE 서브넷 이미 존재${NC}"
else
    az network vnet subnet create \
        --name "$PE_SUBNET_NAME" \
        --vnet-name "$VNET_NAME" \
        --resource-group "$VNET_RG" \
        --address-prefix "$PE_SUBNET_PREFIX" \
        --default-outbound false \
        --private-endpoint-network-policies Disabled
    echo -e "${GREEN}✓ PE 서브넷 생성됨${NC}"
fi

# -----------------------------------------------------------------------------
# NSG 구성
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}NSG 구성 중...${NC}"

# Agent 서브넷 NSG
NSG_AGENT="nsg-${AGENT_SUBNET_NAME}"
if ! az network nsg show --name "$NSG_AGENT" --resource-group "$VNET_RG" &> /dev/null; then
    az network nsg create --name "$NSG_AGENT" --resource-group "$VNET_RG" --location "$LOCATION"
    echo -e "${GREEN}✓ NSG 생성됨: $NSG_AGENT${NC}"
fi

# Agent 서브넷에 NSG 연결
CURRENT_NSG=$(az network vnet subnet show --name "$AGENT_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" \
    --query "networkSecurityGroup.id" -o tsv)
if [ -z "$CURRENT_NSG" ] || [ "$CURRENT_NSG" == "null" ]; then
    az network vnet subnet update \
        --name "$AGENT_SUBNET_NAME" \
        --vnet-name "$VNET_NAME" \
        --resource-group "$VNET_RG" \
        --nsg "$NSG_AGENT"
    echo -e "${GREEN}✓ NSG 연결됨: $AGENT_SUBNET_NAME${NC}"
fi

# PE 서브넷 NSG
NSG_PE="nsg-${PE_SUBNET_NAME}"
if ! az network nsg show --name "$NSG_PE" --resource-group "$VNET_RG" &> /dev/null; then
    az network nsg create --name "$NSG_PE" --resource-group "$VNET_RG" --location "$LOCATION"
    echo -e "${GREEN}✓ NSG 생성됨: $NSG_PE${NC}"
fi

CURRENT_NSG=$(az network vnet subnet show --name "$PE_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" \
    --query "networkSecurityGroup.id" -o tsv)
if [ -z "$CURRENT_NSG" ] || [ "$CURRENT_NSG" == "null" ]; then
    az network vnet subnet update \
        --name "$PE_SUBNET_NAME" \
        --vnet-name "$VNET_NAME" \
        --resource-group "$VNET_RG" \
        --nsg "$NSG_PE"
    echo -e "${GREEN}✓ NSG 연결됨: $PE_SUBNET_NAME${NC}"
fi

# -----------------------------------------------------------------------------
# 결과 출력
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}VNet 구성 요약:${NC}"
echo "  VNet: $VNET_NAME ($VNET_RG)"

AGENT_PREFIX=$(az network vnet subnet show --name "$AGENT_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" \
    --query "addressPrefix" -o tsv)
PE_PREFIX=$(az network vnet subnet show --name "$PE_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" \
    --query "addressPrefix" -o tsv)

echo "  Agent 서브넷: $AGENT_SUBNET_NAME ($AGENT_PREFIX)"
echo "  PE 서브넷: $PE_SUBNET_NAME ($PE_PREFIX)"

# Terraform 변수로 내보내기
cat > "${SCRIPT_DIR}/../vnet.auto.tfvars" << EOF
# Auto-generated by 02-setup-vnet.sh
# VNet이 az cli로 생성되었으므로 Terraform에서 VNet 생성 건너뜀

use_existing_vnet    = true
existing_vnet_name   = "$VNET_NAME"
existing_vnet_rg     = "$VNET_RG"
agent_subnet_name    = "$AGENT_SUBNET_NAME"
pe_subnet_name       = "$PE_SUBNET_NAME"
EOF

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN} [2/8] VNet 구성 완료${NC}"
echo -e "${GREEN}=============================================${NC}"
