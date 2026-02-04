#!/bin/bash
# =============================================================================
# 04-upload-test-data.sh - Blob Storage에 테스트 데이터 업로드
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
echo -e "${BLUE} [4/8] 테스트 데이터 업로드${NC}"
echo -e "${BLUE}=============================================${NC}"

# -----------------------------------------------------------------------------
# Terraform 출력에서 Storage 정보 가져오기
# -----------------------------------------------------------------------------
OUTPUTS_FILE="${SCRIPT_DIR}/../outputs.json"

if [ ! -f "$OUTPUTS_FILE" ]; then
    echo -e "${RED}Error: outputs.json 파일을 찾을 수 없습니다.${NC}"
    echo "03-deploy-ai-foundry.sh를 먼저 실행하세요."
    exit 1
fi

STORAGE_ACCOUNT=$(jq -r '.storage_account_name.value' "$OUTPUTS_FILE")

if [ -z "$STORAGE_ACCOUNT" ] || [ "$STORAGE_ACCOUNT" == "null" ]; then
    echo -e "${RED}Error: Storage Account 이름을 찾을 수 없습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}Storage Account: $STORAGE_ACCOUNT${NC}"

# -----------------------------------------------------------------------------
# 테스트 데이터 디렉토리 확인
# -----------------------------------------------------------------------------
TEST_DATA_DIR="${SCRIPT_DIR}/../test-data"

if [ ! -d "$TEST_DATA_DIR" ]; then
    echo -e "${YELLOW}테스트 데이터 디렉토리 생성 중...${NC}"
    mkdir -p "$TEST_DATA_DIR"
    
    # 샘플 텍스트 파일 생성
    cat > "$TEST_DATA_DIR/sample-document.txt" << 'EOF'
# AI Foundry 테스트 문서

## 개요
이 문서는 AI Foundry Agent Service의 RAG(Retrieval-Augmented Generation) 기능을 테스트하기 위한 샘플 문서입니다.

## 주요 기능
1. **Agent 서비스**: AI 에이전트를 생성하고 관리합니다.
2. **Vector Store**: Azure AI Search를 통해 문서를 벡터화하고 검색합니다.
3. **Thread Storage**: Azure CosmosDB를 통해 대화 이력을 저장합니다.
4. **File Storage**: Azure Blob Storage를 통해 파일을 저장합니다.

## 기술 사양
- 지원 모델: GPT-4o, GPT-4.1
- 네트워크: Private Endpoint 지원
- 인증: Azure AD (Managed Identity)

## 자주 묻는 질문
Q: Agent 서비스의 최대 동시 연결 수는?
A: 기본 설정에서 100개의 동시 연결을 지원합니다.

Q: 문서 업로드 크기 제한은?
A: 단일 파일당 최대 512MB까지 지원합니다.
EOF

    cat > "$TEST_DATA_DIR/product-catalog.txt" << 'EOF'
# 제품 카탈로그 2026

## 엔터프라이즈 AI 솔루션

### AI Foundry Standard
- 가격: $1,000/월
- 포함 기능: Agent 서비스, Vector Store, 기본 지원
- 최대 사용자: 100명

### AI Foundry Professional  
- 가격: $5,000/월
- 포함 기능: 모든 Standard 기능 + 고급 분석, 프리미엄 지원
- 최대 사용자: 500명

### AI Foundry Enterprise
- 가격: 맞춤 견적
- 포함 기능: 모든 Professional 기능 + 전용 인프라, 24/7 지원
- 최대 사용자: 무제한

## 부가 서비스
- 컨설팅: $200/시간
- 맞춤 개발: 프로젝트별 견적
- 교육: $500/인/일
EOF

    cat > "$TEST_DATA_DIR/faq-document.txt" << 'EOF'
# 자주 묻는 질문 (FAQ)

## 계정 관련

Q: 계정을 어떻게 생성하나요?
A: Azure Portal에서 AI Foundry 리소스를 생성하면 자동으로 계정이 생성됩니다.

Q: 비밀번호를 잊어버렸어요.
A: Azure AD를 통해 인증하므로, Azure AD에서 비밀번호를 재설정하세요.

## 기술 관련

Q: Private Endpoint를 설정하는 방법은?
A: VNet에 Private Endpoint를 생성하고, Private DNS Zone을 연결하면 됩니다.

Q: 모델 배포에 실패했어요.
A: 할당량(Quota)을 확인하고, 해당 리전에서 모델이 지원되는지 확인하세요.

Q: Capability Host 생성이 실패했어요.
A: RBAC 역할이 올바르게 할당되었는지, Private Endpoint가 Succeeded 상태인지 확인하세요.

## 비용 관련

Q: 비용은 어떻게 청구되나요?
A: 사용한 토큰 수, 저장소 용량, 검색 쿼리 수에 따라 청구됩니다.

Q: 무료 체험이 있나요?
A: 신규 Azure 계정에는 $200 크레딧이 제공됩니다.
EOF

    echo -e "${GREEN}✓ 샘플 테스트 데이터 생성됨${NC}"
fi

# -----------------------------------------------------------------------------
# Blob Container 생성
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}Blob Container 확인/생성 중...${NC}"

# Managed Identity 인증 사용
if ! az storage container show --name "$TEST_DATA_CONTAINER" --account-name "$STORAGE_ACCOUNT" --auth-mode login &> /dev/null; then
    az storage container create \
        --name "$TEST_DATA_CONTAINER" \
        --account-name "$STORAGE_ACCOUNT" \
        --auth-mode login
    echo -e "${GREEN}✓ Container 생성됨: $TEST_DATA_CONTAINER${NC}"
else
    echo -e "${GREEN}✓ Container 이미 존재: $TEST_DATA_CONTAINER${NC}"
fi

# -----------------------------------------------------------------------------
# 파일 업로드
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}파일 업로드 중...${NC}"

for file in "$TEST_DATA_DIR"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo -e "  → $filename 업로드 중..."
        
        az storage blob upload \
            --file "$file" \
            --name "$filename" \
            --container-name "$TEST_DATA_CONTAINER" \
            --account-name "$STORAGE_ACCOUNT" \
            --auth-mode login \
            --overwrite
    fi
done

echo -e "${GREEN}✓ 모든 파일 업로드 완료${NC}"

# -----------------------------------------------------------------------------
# 업로드된 파일 확인
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}업로드된 파일 목록:${NC}"
az storage blob list \
    --container-name "$TEST_DATA_CONTAINER" \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login \
    --query "[].{Name:name, Size:properties.contentLength}" \
    -o table

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN} [4/8] 테스트 데이터 업로드 완료${NC}"
echo -e "${GREEN}=============================================${NC}"
