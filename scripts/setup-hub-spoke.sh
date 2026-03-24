#!/bin/bash
# =============================================================================
# Hub VNet 구성 스크립트
# =============================================================================
# AI Foundry Classic (Managed VNet) 환경을 위한 Hub VNet 생성
#
# 토폴로지:
#   On-prem VNet (172.16.x.x) ←→ Hub VNet (10.0.0.0/16) ←→ AI Foundry Managed VNet
#   (Bicep으로 배포)               (이 스크립트)               (Hub가 자동 관리)
#
# 사용법:
#   ./scripts/setup-hub-spoke.sh
#   ./scripts/setup-hub-spoke.sh --location swedencentral --env dev
# =============================================================================

set -euo pipefail

# =============================================================================
# 기본 설정
# =============================================================================
LOCATION="${LOCATION:-swedencentral}"
ENV="${ENV:-dev}"

# 리전 약어 매핑
case "${LOCATION}" in
  swedencentral)   REGION_SHORT="swc" ;;
  koreacentral)    REGION_SHORT="krc" ;;
  eastus)          REGION_SHORT="eus" ;;
  westus)          REGION_SHORT="wus" ;;
  westeurope)      REGION_SHORT="weu" ;;
  *)               REGION_SHORT=$(echo "${LOCATION}" | cut -c1-3) ;;
esac

HUB_RG="rg-aif-hub-${REGION_SHORT}-${ENV}"

HUB_VNET_NAME="vnet-hub-${ENV}"
HUB_VNET_PREFIX="10.0.0.0/16"
HUB_GATEWAY_SUBNET_PREFIX="10.0.0.0/27"
HUB_SHARED_SUBNET_PREFIX="10.0.1.0/24"

# =============================================================================
# 인자 파싱
# =============================================================================
while [[ $# -gt 0 ]]; do
  case $1 in
    --location) LOCATION="$2"; shift 2 ;;
    --env) ENV="$2"; shift 2 ;;
    --hub-rg) HUB_RG="$2"; shift 2 ;;
    -h|--help)
      echo "사용법: $0 [옵션]"
      echo "  --location   Azure 리전 (기본: swedencentral)"
      echo "  --env        환경 이름 (기본: dev)"
      echo "  --hub-rg     Hub 리소스 그룹 (기본: rg-aif-hub-{region}-{env})"
      exit 0
      ;;
    *) echo "알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

# 인자 파싱 후 리전 약어 재계산
case "${LOCATION}" in
  swedencentral)   REGION_SHORT="swc" ;;
  koreacentral)    REGION_SHORT="krc" ;;
  eastus)          REGION_SHORT="eus" ;;
  westus)          REGION_SHORT="wus" ;;
  westeurope)      REGION_SHORT="weu" ;;
  *)               REGION_SHORT=$(echo "${LOCATION}" | cut -c1-3) ;;
esac

# 환경에 따라 리소스 그룹 이름 재설정
HUB_RG="rg-aif-hub-${REGION_SHORT}-${ENV}"

echo "============================================="
echo " Hub VNet 구성"
echo "============================================="
echo " Location:    ${LOCATION}"
echo " Environment: ${ENV}"
echo " Hub RG:      ${HUB_RG}"
echo " Hub VNet:    ${HUB_VNET_NAME} (${HUB_VNET_PREFIX})"
echo "============================================="
echo ""

# =============================================================================
# Step 1: 리소스 그룹 생성
# =============================================================================
echo "[1/3] 리소스 그룹 생성..."

az group create --name "${HUB_RG}" --location "${LOCATION}" \
  --tags Environment="${ENV}" Purpose="NetworkHub" ManagedBy="CLI" \
  --output none

echo "  ✅ ${HUB_RG} 생성 완료"

# =============================================================================
# Step 2: Hub VNet 생성
# =============================================================================
echo "[2/3] Hub VNet 생성..."

az network vnet create \
  --resource-group "${HUB_RG}" \
  --name "${HUB_VNET_NAME}" \
  --address-prefixes "${HUB_VNET_PREFIX}" \
  --location "${LOCATION}" \
  --tags Environment="${ENV}" Purpose="NetworkHub" \
  --output none

# GatewaySubnet (VPN/ExpressRoute용, 향후 확장)
az network vnet subnet create \
  --resource-group "${HUB_RG}" \
  --vnet-name "${HUB_VNET_NAME}" \
  --name GatewaySubnet \
  --address-prefixes "${HUB_GATEWAY_SUBNET_PREFIX}" \
  --output none

# Shared Services Subnet (DNS, AD 등)
az network vnet subnet create \
  --resource-group "${HUB_RG}" \
  --vnet-name "${HUB_VNET_NAME}" \
  --name snet-shared-services \
  --address-prefixes "${HUB_SHARED_SUBNET_PREFIX}" \
  --output none

echo "  ✅ Hub VNet (${HUB_VNET_NAME}) 생성 완료"
echo "      - GatewaySubnet:         ${HUB_GATEWAY_SUBNET_PREFIX}"
echo "      - snet-shared-services:  ${HUB_SHARED_SUBNET_PREFIX}"

# =============================================================================
# Step 3: Hub VNet ID 출력
# =============================================================================
echo "[3/3] Hub VNet ID 조회..."

HUB_VNET_ID=$(az network vnet show \
  --resource-group "${HUB_RG}" \
  --name "${HUB_VNET_NAME}" \
  --query id --output tsv)

echo ""
echo "============================================="
echo " Hub VNet 구성 완료"
echo "============================================="
echo ""
echo " Hub VNet ID: ${HUB_VNET_ID}"
echo ""
echo " 다음 단계:"
echo ""
echo "   1. AI Foundry Classic Basic 배포:"
echo "      cd infra-foundry-classic/basic"
echo "      az deployment sub create --location ${LOCATION} \\"
echo "        --template-file main.bicep \\"
echo "        --parameters parameters/dev.bicepparam"
echo ""
echo "   2. Jumpbox (On-prem 시뮬레이션) 배포:"
echo "      cd infra-foundry-classic/jumpbox"
echo "      az deployment sub create --location ${LOCATION} \\"
echo "        --template-file main.bicep \\"
echo "        --parameters parameters/dev.bicepparam \\"
echo "        --parameters hubVnetId='${HUB_VNET_ID}' \\"
echo "        --parameters adminPassword='<비밀번호>'"
echo ""
echo "   3. (선택) Hub에 VPN Gateway 추가 (On-premises 연결)"
echo "============================================="
