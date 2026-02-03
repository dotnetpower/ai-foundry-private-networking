#!/bin/bash
# =============================================================================
# AI Foundry 배포 검증 스크립트
# 
# 이 스크립트는 배포된 AI Foundry 인프라를 자동으로 검증합니다.
#
# 사용법:
#   chmod +x verify-deployment.sh
#   ./verify-deployment.sh
#
# 검증 항목:
#   1. Azure 연결 및 리소스 존재 확인
#   2. Private Endpoint DNS 해석 테스트
#   3. Storage Account 접근 테스트
#   4. AI Search 검색 테스트
#   5. Azure OpenAI 모델 배포 확인
#   6. AI Foundry Hub/Project 확인
#   7. RAG 패턴 End-to-End 테스트
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 결과 카운터
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# =============================================================================
# 함수 정의
# =============================================================================

print_header() {
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}=============================================${NC}"
}

print_section() {
    echo -e "\n${YELLOW}[Test $1] $2${NC}"
}

test_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    ((PASS_COUNT++))
}

test_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    ((FAIL_COUNT++))
}

test_warn() {
    echo -e "${YELLOW}⚠ WARN: $1${NC}"
    ((WARN_COUNT++))
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# =============================================================================
# 환경 변수 설정
# =============================================================================

print_header "AI Foundry 배포 검증 스크립트"

# 기본값 (Terraform output에서 자동으로 가져옴)
RESOURCE_GROUP=${RESOURCE_GROUP:-"rg-aifoundry-20260203"}
STORAGE_ACCOUNT=${STORAGE_ACCOUNT:-"staifoundry20260203"}
SEARCH_SERVICE=${SEARCH_SERVICE:-"srch-aifoundry-7kkykgt6"}
AI_HUB=${AI_HUB:-"aihub-foundry"}
AI_PROJECT=${AI_PROJECT:-"aiproj-agents"}
CONTAINER_NAME=${CONTAINER_NAME:-"documents"}
INDEX_NAME=${INDEX_NAME:-"aifoundry-docs-index"}

echo -e "\n환경 설정:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Search Service: $SEARCH_SERVICE"
echo "  AI Hub: $AI_HUB"
echo "  AI Project: $AI_PROJECT"

# =============================================================================
# Test 1: Azure 연결 확인
# =============================================================================

print_section "1/7" "Azure 연결 확인"

# Azure CLI 확인
if command -v az &> /dev/null; then
    test_pass "Azure CLI 설치 확인"
else
    test_fail "Azure CLI가 설치되어 있지 않습니다"
    exit 1
fi

# Azure 로그인 확인
if az account show &> /dev/null; then
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    test_pass "Azure 로그인 확인: $SUBSCRIPTION_NAME"
else
    test_fail "Azure에 로그인되어 있지 않습니다"
    exit 1
fi

# =============================================================================
# Test 2: 리소스 존재 확인
# =============================================================================

print_section "2/7" "리소스 존재 확인"

# Resource Group
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    test_pass "Resource Group 존재: $RESOURCE_GROUP"
else
    test_fail "Resource Group이 존재하지 않습니다: $RESOURCE_GROUP"
    exit 1
fi

# Storage Account
if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    test_pass "Storage Account 존재: $STORAGE_ACCOUNT"
else
    test_fail "Storage Account가 존재하지 않습니다: $STORAGE_ACCOUNT"
fi

# AI Search
if az search service show --name "$SEARCH_SERVICE" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    SEARCH_STATUS=$(az search service show \
        --name "$SEARCH_SERVICE" \
        --resource-group "$RESOURCE_GROUP" \
        --query status -o tsv)
    
    if [ "$SEARCH_STATUS" == "running" ]; then
        test_pass "AI Search Service 정상: $SEARCH_SERVICE (Status: $SEARCH_STATUS)"
    else
        test_warn "AI Search Service 상태 확인 필요: $SEARCH_STATUS"
    fi
else
    test_fail "AI Search Service가 존재하지 않습니다: $SEARCH_SERVICE"
fi

# AI Hub
if az ml workspace show --name "$AI_HUB" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    test_pass "AI Hub 존재: $AI_HUB"
else
    test_fail "AI Hub가 존재하지 않습니다: $AI_HUB"
fi

# =============================================================================
# Test 3: Private Endpoint DNS 해석 테스트
# =============================================================================

print_section "3/7" "Private Endpoint DNS 해석 테스트"

# Storage Blob DNS
STORAGE_BLOB_FQDN="${STORAGE_ACCOUNT}.blob.core.windows.net"
print_info "Testing: $STORAGE_BLOB_FQDN"

if host "$STORAGE_BLOB_FQDN" | grep -q "10.0.1"; then
    IP=$(host "$STORAGE_BLOB_FQDN" | grep "has address" | awk '{print $4}' | head -1)
    test_pass "Storage Blob Private DNS 정상 (IP: $IP)"
else
    test_warn "Storage Blob이 Public IP로 해석됩니다. Private Endpoint를 확인하세요."
fi

# AI Search DNS
SEARCH_FQDN="${SEARCH_SERVICE}.search.windows.net"
print_info "Testing: $SEARCH_FQDN"

if host "$SEARCH_FQDN" | grep -q "10.0.1"; then
    IP=$(host "$SEARCH_FQDN" | grep "has address" | awk '{print $4}' | head -1)
    test_pass "AI Search Private DNS 정상 (IP: $IP)"
else
    test_warn "AI Search가 Public IP로 해석됩니다. Private Endpoint를 확인하세요."
fi

# AI Hub DNS
AI_HUB_FQDN="${AI_HUB}.api.azureml.ms"
print_info "Testing: $AI_HUB_FQDN"

if host "$AI_HUB_FQDN" | grep -q "10.0.1"; then
    IP=$(host "$AI_HUB_FQDN" | grep "has address" | awk '{print $4}' | head -1)
    test_pass "AI Hub Private DNS 정상 (IP: $IP)"
else
    test_warn "AI Hub가 Public IP로 해석됩니다. Private Endpoint를 확인하세요."
fi

# =============================================================================
# Test 4: Storage Account 접근 테스트
# =============================================================================

print_section "4/7" "Storage Account 접근 테스트"

# Container 존재 확인
if az storage container exists \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login \
    --query exists -o tsv 2>&1 | grep -q "true"; then
    test_pass "Container 존재: $CONTAINER_NAME"
else
    test_warn "Container가 존재하지 않습니다: $CONTAINER_NAME"
fi

# Blob 목록 조회 테스트
BLOB_COUNT=$(az storage blob list \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER_NAME" \
    --auth-mode login \
    --query "length(@)" -o tsv 2>/dev/null || echo "0")

if [ "$BLOB_COUNT" -gt 0 ]; then
    test_pass "Blob 목록 조회 성공 (파일 수: $BLOB_COUNT)"
else
    test_warn "Container에 파일이 없습니다. 테스트 문서를 업로드하세요."
fi

# =============================================================================
# Test 5: AI Search 검색 테스트
# =============================================================================

print_section "5/7" "AI Search 검색 테스트"

SEARCH_ENDPOINT="https://${SEARCH_SERVICE}.search.windows.net"

# 인덱스 존재 확인
print_info "인덱스 확인 중: $INDEX_NAME"

TOKEN=$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)

INDEX_CHECK=$(curl -s -X GET \
    "${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}?api-version=2024-07-01" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" 2>/dev/null | jq -r '.name // empty')

if [ "$INDEX_CHECK" == "$INDEX_NAME" ]; then
    test_pass "AI Search 인덱스 존재: $INDEX_NAME"
    
    # 문서 수 확인
    DOC_COUNT=$(curl -s -X GET \
        "${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}/docs/\$count?api-version=2024-07-01" \
        -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)
    
    if [ "$DOC_COUNT" -gt 0 ]; then
        test_pass "인덱싱된 문서 수: $DOC_COUNT"
    else
        test_warn "인덱싱된 문서가 없습니다. Indexer를 실행하세요."
    fi
    
    # 검색 테스트
    print_info "검색 테스트 실행: 'AI Foundry'"
    
    SEARCH_RESULT=$(curl -s -X POST \
        "${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}/docs/search?api-version=2024-07-01" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "search": "AI Foundry",
            "top": 1,
            "select": "title"
        }' 2>/dev/null | jq -r '.value | length')
    
    if [ "$SEARCH_RESULT" -gt 0 ]; then
        test_pass "AI Search 검색 성공 (결과 수: $SEARCH_RESULT)"
    else
        test_warn "검색 결과가 없습니다. 문서를 업로드하고 인덱싱하세요."
    fi
else
    test_fail "AI Search 인덱스가 존재하지 않습니다: $INDEX_NAME"
fi

# =============================================================================
# Test 6: Azure OpenAI 모델 배포 확인
# =============================================================================

print_section "6/7" "Azure OpenAI 모델 배포 확인"

# OpenAI 계정 찾기
OPENAI_ACCOUNT=$(az cognitiveservices account list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?kind=='OpenAI'].name" -o tsv 2>/dev/null | head -1)

if [ -n "$OPENAI_ACCOUNT" ]; then
    test_pass "Azure OpenAI 계정 존재: $OPENAI_ACCOUNT"
    
    # GPT-4o 배포 확인
    GPT4O_DEPLOYMENT=$(az cognitiveservices account deployment list \
        --name "$OPENAI_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?model.name=='gpt-4o'].name" -o tsv 2>/dev/null | head -1)
    
    if [ -n "$GPT4O_DEPLOYMENT" ]; then
        test_pass "GPT-4o 모델 배포됨: $GPT4O_DEPLOYMENT"
    else
        test_warn "GPT-4o 모델이 배포되지 않았습니다"
    fi
    
    # Embedding 모델 배포 확인
    EMBEDDING_DEPLOYMENT=$(az cognitiveservices account deployment list \
        --name "$OPENAI_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?model.name=='text-embedding-ada-002'].name" -o tsv 2>/dev/null | head -1)
    
    if [ -n "$EMBEDDING_DEPLOYMENT" ]; then
        test_pass "Embedding 모델 배포됨: $EMBEDDING_DEPLOYMENT"
    else
        test_warn "Embedding 모델이 배포되지 않았습니다 (벡터 검색에 필요)"
    fi
else
    test_fail "Azure OpenAI 계정을 찾을 수 없습니다"
fi

# =============================================================================
# Test 7: End-to-End RAG 패턴 테스트
# =============================================================================

print_section "7/7" "End-to-End RAG 패턴 테스트"

if [ -n "$OPENAI_ACCOUNT" ] && [ -n "$GPT4O_DEPLOYMENT" ] && [ "$DOC_COUNT" -gt 0 ]; then
    print_info "RAG 패턴 테스트 실행 중..."
    
    # 1. AI Search로 문서 검색
    SEARCH_QUERY="Azure AI Foundry"
    SEARCH_RESULTS=$(curl -s -X POST \
        "${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}/docs/search?api-version=2024-07-01" \
        -H "Authorization: Bearer $(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)" \
        -H "Content-Type: application/json" \
        -d "{
            \"search\": \"$SEARCH_QUERY\",
            \"top\": 2,
            \"select\": \"title, content\"
        }" 2>/dev/null)
    
    SEARCH_COUNT=$(echo "$SEARCH_RESULTS" | jq -r '.value | length')
    
    if [ "$SEARCH_COUNT" -gt 0 ]; then
        test_pass "Step 1: AI Search 검색 성공 (결과: $SEARCH_COUNT개)"
        
        # 검색된 문서 제목 출력
        echo "$SEARCH_RESULTS" | jq -r '.value[].title' | while read -r title; do
            print_info "  → $title"
        done
        
        # 2. 검색 결과를 컨텍스트로 변환
        CONTEXT=$(echo "$SEARCH_RESULTS" | jq -r '.value[] | "[" + .title + "]\n" + .content' | head -c 500)
        
        # 3. GPT-4o 호출 (간단한 테스트)
        OPENAI_ENDPOINT=$(az cognitiveservices account show \
            --name "$OPENAI_ACCOUNT" \
            --resource-group "$RESOURCE_GROUP" \
            --query properties.endpoint -o tsv)
        
        OPENAI_TOKEN=$(az account get-access-token \
            --resource https://cognitiveservices.azure.com \
            --query accessToken -o tsv)
        
        GPT_RESPONSE=$(curl -s -X POST \
            "${OPENAI_ENDPOINT}/openai/deployments/${GPT4O_DEPLOYMENT}/chat/completions?api-version=2024-10-21" \
            -H "Authorization: Bearer ${OPENAI_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"messages\": [
                    {
                        \"role\": \"system\",
                        \"content\": \"You are a helpful assistant. Context: ${CONTEXT}\"
                    },
                    {
                        \"role\": \"user\",
                        \"content\": \"What is Azure AI Foundry?\"
                    }
                ],
                \"temperature\": 0.7,
                \"max_tokens\": 100
            }" 2>/dev/null | jq -r '.choices[0].message.content // empty')
        
        if [ -n "$GPT_RESPONSE" ]; then
            test_pass "Step 2: GPT-4o 응답 생성 성공"
            print_info "응답 미리보기: $(echo "$GPT_RESPONSE" | head -c 100)..."
            test_pass "End-to-End RAG 패턴 테스트 성공!"
        else
            test_warn "GPT-4o 응답 생성 실패. OpenAI 엔드포인트를 확인하세요."
        fi
    else
        test_warn "검색 결과가 없어 RAG 패턴 테스트를 건너뜁니다"
    fi
else
    test_warn "RAG 패턴 테스트 조건이 충족되지 않았습니다 (OpenAI 모델 또는 문서 필요)"
fi

# =============================================================================
# 결과 요약
# =============================================================================

print_header "검증 결과 요약"

echo -e "\n${GREEN}✓ PASS: $PASS_COUNT${NC}"
echo -e "${YELLOW}⚠ WARN: $WARN_COUNT${NC}"
echo -e "${RED}✗ FAIL: $FAIL_COUNT${NC}"

# 전체 결과 판정
TOTAL_TESTS=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
echo -e "\n총 테스트: $TOTAL_TESTS"

if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
    echo -e "\n${GREEN}🎉 모든 테스트가 성공했습니다!${NC}"
    echo -e "${GREEN}AI Foundry 인프라가 정상적으로 배포되었습니다.${NC}"
    exit 0
elif [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "\n${YELLOW}⚠️ 일부 경고가 있지만 배포는 정상입니다.${NC}"
    echo -e "${YELLOW}경고 항목을 검토하세요.${NC}"
    exit 0
else
    echo -e "\n${RED}❌ 일부 테스트가 실패했습니다.${NC}"
    echo -e "${RED}문제를 해결한 후 다시 실행하세요.${NC}"
    exit 1
fi
