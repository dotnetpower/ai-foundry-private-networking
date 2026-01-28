#!/bin/bash
set -e

# 컬러 출력 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== AI Foundry Infrastructure Deployment ===${NC}"

# Terraform 작업 디렉토리로 이동
cd "$(dirname "$0")/.."

# 1. 기존 리소스 정리
echo -e "${YELLOW}1단계: 기존 리소스 정리 중...${NC}"
if az group show --name rg-aifoundry-dev &>/dev/null; then
    echo "리소스 그룹 삭제 시작..."
    az group delete --name rg-aifoundry-dev --yes --no-wait
    
    echo "리소스 그룹 삭제 완료 대기 중..."
    while az group show --name rg-aifoundry-dev &>/dev/null; do
        echo -n "."
        sleep 10
    done
    echo -e "\n${GREEN}리소스 그룹 삭제 완료${NC}"
fi

# 2. Soft-deleted 리소스 정리
echo -e "${YELLOW}2단계: Soft-deleted 리소스 정리 중...${NC}"

# Azure OpenAI purge
if az cognitiveservices account list-deleted --query "[?name=='aoai-aifoundry']" -o tsv 2>/dev/null | grep -q "aoai-aifoundry"; then
    echo "Azure OpenAI soft-deleted 리소스 purge 중..."
    az cognitiveservices account purge --name aoai-aifoundry --resource-group rg-aifoundry-dev --location koreacentral 2>/dev/null || true
    az cognitiveservices account purge --name aoai-aifoundry --resource-group rg-aifoundry-dev --location eastus 2>/dev/null || true
fi

# Key Vault purge
if az keyvault list-deleted --query "[?name=='kv-aif-x6mo8jxq']" -o tsv 2>/dev/null | grep -q "kv-aif-x6mo8jxq"; then
    echo "Key Vault soft-deleted 리소스 purge 중..."
    az keyvault purge --name kv-aif-x6mo8jxq --location eastus 2>/dev/null || true
fi

echo -e "${GREEN}정리 완료${NC}"
sleep 5

# 3. Terraform State 초기화
echo -e "${YELLOW}3단계: Terraform state 초기화 중...${NC}"
rm -f terraform.tfstate*
terraform init -reconfigure -backend-config="environments/dev/backend.tfvars"

# 4. Terraform Plan 생성
echo -e "${YELLOW}4단계: Terraform plan 생성 중...${NC}"
terraform plan -var-file="environments/dev/terraform.tfvars" -out=tfplan

# 5. 사용자 확인 및 배포
echo -e "${YELLOW}위 plan을 확인하세요.${NC}"
read -p "배포를 진행하시겠습니까? (yes/no): " response

if [ "$response" = "yes" ]; then
    echo -e "${GREEN}5단계: 배포를 시작합니다...${NC}"
    terraform apply tfplan
    echo -e "${GREEN}배포 완료!${NC}"
    
    # 6. 배포 결과 출력
    echo -e "\n${GREEN}=== 배포 결과 ===${NC}"
    terraform output
else
    echo -e "${RED}배포가 취소되었습니다.${NC}"
    exit 1
fi
