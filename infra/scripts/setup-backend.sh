#!/bin/bash
set -e

# AI Foundry Private Networking - Terraform Backend 설정 스크립트
# 이 스크립트는 Azure에 Terraform state를 저장할 원격 backend를 생성합니다

echo "=========================================="
echo "Terraform Backend 설정 시작"
echo "=========================================="

# 변수 설정
RESOURCE_GROUP="rg-terraform-state-dev"
STORAGE_ACCOUNT="staifoundrytfstate"
CONTAINER_NAME="tfstate"
LOCATION="koreacentral"

# 1. Resource Group 생성
echo ""
echo "[1/4] Resource Group 생성 중..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

echo "✓ Resource Group 생성 완료: $RESOURCE_GROUP"

# 2. Storage Account 생성
echo ""
echo "[2/4] Storage Account 생성 중..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-shared-key-access false \
  --output none

echo "✓ Storage Account 생성 완료: $STORAGE_ACCOUNT"

# 3. Blob Container 생성
echo ""
echo "[3/4] Blob Container 생성 중..."
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none

echo "✓ Blob Container 생성 완료: $CONTAINER_NAME"

# 4. RBAC 권한 할당
echo ""
echo "[4/4] RBAC 권한 할당 중..."
USER_ID=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$USER_ID" \
  --scope "$STORAGE_ID" \
  --output none

echo "✓ RBAC 권한 할당 완료"

# 완료
echo ""
echo "=========================================="
echo "✓ Terraform Backend 설정 완료!"
echo "=========================================="
echo ""
echo "Backend 정보:"
echo "  Resource Group:   $RESOURCE_GROUP"
echo "  Storage Account:  $STORAGE_ACCOUNT"
echo "  Container:        $CONTAINER_NAME"
echo "  Location:         $LOCATION"
echo ""
echo "다음 단계:"
echo "  1. main.tf에서 backend 블록 주석 해제"
echo "  2. ./scripts/init-terraform.sh 실행"
echo ""
