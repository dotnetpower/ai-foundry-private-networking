#!/bin/bash
set -e

# 컬러 출력 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 배포 날짜 설정 (인자로 전달되거나 현재 날짜 사용)
DEPLOY_DATE=${1:-$(date +%Y%m%d)}
PROJECT_NAME="aifoundry"
RESOURCE_GROUP_NAME="rg-${PROJECT_NAME}-${DEPLOY_DATE}"
STORAGE_ACCOUNT_NAME="st${PROJECT_NAME}${DEPLOY_DATE}"

echo -e "${GREEN}=== AI Foundry 완전 초기화 및 재배포 ===${NC}"
echo -e "${BLUE}배포 날짜: ${DEPLOY_DATE}${NC}"
echo -e "${BLUE}리소스 그룹: ${RESOURCE_GROUP_NAME}${NC}"
echo -e "${BLUE}스토리지 계정: ${STORAGE_ACCOUNT_NAME}${NC}"
echo ""

# Terraform 작업 디렉토리로 이동
cd "$(dirname "$0")/.."

# 1. 기존 rg-aifoundry-* 패턴 리소스 그룹 정리
echo -e "${YELLOW}1단계: 기존 리소스 정리 중...${NC}"

# rg-aifoundry-로 시작하는 모든 리소스 그룹 검색 및 삭제
EXISTING_RGS=$(az group list --query "[?starts_with(name, 'rg-${PROJECT_NAME}-')].name" -o tsv 2>/dev/null || echo "")
if [ -n "$EXISTING_RGS" ]; then
    echo "발견된 리소스 그룹:"
    echo "$EXISTING_RGS"
    for rg in $EXISTING_RGS; do
        echo "  삭제 중: $rg"
        az group delete --name "$rg" --yes --no-wait 2>/dev/null || true
    done
    
    echo "리소스 그룹 삭제 완료 대기 중..."
    for rg in $EXISTING_RGS; do
        while az group show --name "$rg" &>/dev/null; do
            echo -n "."
            sleep 10
        done
    done
    echo -e "\n${GREEN}리소스 그룹 삭제 완료${NC}"
else
    echo "삭제할 리소스 그룹이 없습니다."
fi

# 2. Soft-deleted 리소스 정리 (모든 가능한 위치)
echo -e "${YELLOW}2단계: Soft-deleted 리소스 정리 중...${NC}"

# 모든 soft-deleted Cognitive Services 조회 및 purge
echo "Soft-deleted Cognitive Services 검색 중..."
DELETED_COGNITIVE=$(az cognitiveservices account list-deleted --query "[?name=='aoai-aifoundry'].{name:name,location:location}" -o json)
if [ "$DELETED_COGNITIVE" != "[]" ]; then
    echo "$DELETED_COGNITIVE" | jq -r '.[] | "\(.name) \(.location)"' | while read name location; do
        echo "  Purging: $name in $location"
        az cognitiveservices account purge --name "$name" --resource-group rg-aifoundry-dev --location "$location" 2>/dev/null || true
    done
fi

# 모든 soft-deleted Key Vault 조회 및 purge
echo "Soft-deleted Key Vault 검색 중..."
DELETED_VAULTS=$(az keyvault list-deleted --query "[?starts_with(name, 'kv-aif-')].{name:name,location:location}" -o json)
if [ "$DELETED_VAULTS" != "[]" ]; then
    echo "$DELETED_VAULTS" | jq -r '.[] | "\(.name) \(.location)"' | while read name location; do
        echo "  Purging: $name in $location"
        az keyvault purge --name "$name" --location "$location" 2>/dev/null || true
    done
fi

echo -e "${GREEN}정리 완료${NC}"
sleep 10

# 3. Terraform 완전 초기화 (random_string state 포함)
echo -e "${YELLOW}3단계: Terraform 완전 초기화 중...${NC}"
rm -rf .terraform
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*
rm -f tfplan

# Backend 재초기화
terraform init -reconfigure -backend-config="environments/dev/backend.tfvars"
echo -e "${GREEN}Terraform 초기화 완료 (새로운 random suffix 생성됨)${NC}"

# 4. Terraform Validate
echo -e "${YELLOW}4단계: Terraform 검증 중...${NC}"
terraform fmt -recursive
terraform validate
echo -e "${GREEN}검증 완료${NC}"

# 5. Terraform Plan 생성 (배포 날짜 전달)
echo -e "${YELLOW}5단계: Terraform plan 생성 중...${NC}"
echo -e "${BLUE}배포 날짜: ${DEPLOY_DATE}${NC}"
terraform plan -var-file="environments/dev/terraform.tfvars" -var="deploy_date=${DEPLOY_DATE}" -out=tfplan

# 6. 사용자 확인 및 배포
echo -e "\n${YELLOW}=== 배포 계획 확인 ===${NC}"
echo -e "${BLUE}리소스 그룹: ${RESOURCE_GROUP_NAME}${NC}"
echo -e "${BLUE}스토리지 계정: ${STORAGE_ACCOUNT_NAME}${NC}"
echo -e "${YELLOW}위 plan을 확인하세요.${NC}"
read -p "배포를 진행하시겠습니까? (yes/no): " response

if [ "$response" = "yes" ]; then
    echo -e "${GREEN}6단계: 배포를 시작합니다...${NC}"
    terraform apply tfplan
    echo -e "${GREEN}배포 완료!${NC}"
    
    # 7. 배포 결과 출력
    echo -e "\n${GREEN}=== 배포 결과 ===${NC}"
    terraform output
    
    # 8. 배포 정보 저장
    echo -e "\n${GREEN}=== 배포 정보를 deploy-info-${DEPLOY_DATE}.txt에 저장 중... ===${NC}"
    {
        echo "배포 날짜: ${DEPLOY_DATE}"
        echo "배포 시간: $(date)"
        echo "리소스 그룹: ${RESOURCE_GROUP_NAME}"
        echo "스토리지 계정: ${STORAGE_ACCOUNT_NAME}"
        echo ""
        terraform output
    } > "deploy-info-${DEPLOY_DATE}.txt"
    echo -e "${GREEN}배포 정보 저장 완료: deploy-info-${DEPLOY_DATE}.txt${NC}"
else
    echo -e "${RED}배포가 취소되었습니다.${NC}"
    rm -f tfplan
    exit 1
fi
