#!/bin/bash
# =============================================================================
# Jumpbox 오프라인 배포 스크립트 (Bash)
# 
# 이 스크립트는 인터넷 연결이 제한된 Jumpbox 환경에서 
# AI Foundry 리소스를 구성하고 테스트하는 데 사용됩니다.
#
# 사용법:
#   chmod +x jumpbox-offline-deploy.sh
#   ./jumpbox-offline-deploy.sh
#
# 실행 환경:
#   - Linux Jumpbox (Ubuntu 22.04)
#   - Azure CLI 설치 필요
#   - Private Network 접근 가능
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# 함수 정의
# =============================================================================

# 헤더 출력
print_header() {
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}=============================================${NC}"
}

# 섹션 출력
print_section() {
    echo -e "\n${YELLOW}[Step $1] $2${NC}"
}

# 성공 메시지
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 오류 메시지
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# 경고 메시지
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 정보 메시지
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# 사용자 입력 받기
get_input() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ -n "$default" ]; then
        read -p "$(echo -e ${BLUE}$prompt [$default]: ${NC})" result
        result="${result:-$default}"
    else
        read -p "$(echo -e ${BLUE}$prompt: ${NC})" result
    fi
    
    echo "$result"
}

# 명령 실행 및 결과 확인
run_command() {
    local description="$1"
    shift
    
    echo -e "${CYAN}→ $description${NC}"
    if "$@" 2>&1 | tee -a deploy.log; then
        print_success "$description 완료"
        return 0
    else
        print_error "$description 실패"
        return 1
    fi
}

# =============================================================================
# 메인 스크립트
# =============================================================================

clear
print_header "AI Foundry Private Networking - Jumpbox 배포 스크립트"

echo -e "\n${MAGENTA}이 스크립트는 다음 작업을 수행합니다:${NC}"
echo "  1. Azure 연결 확인"
echo "  2. 리소스 그룹 및 주요 리소스 확인"
echo "  3. Private Endpoint DNS 해석 테스트"
echo "  4. Storage Account 구성"
echo "  5. AI Search 인덱스 생성"
echo "  6. 테스트 문서 업로드"
echo "  7. AI Foundry 연결 테스트"
echo "  8. Playground 예제 코드 생성"
echo ""

# 계속 진행 확인
read -p "$(echo -e ${YELLOW}계속 진행하시겠습니까? [y/N]: ${NC})" confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "스크립트를 종료합니다."
    exit 0
fi

# =============================================================================
# Step 1: 환경 변수 설정
# =============================================================================

print_section "1/8" "환경 변수 설정"

# 기본값 설정
DEFAULT_RESOURCE_GROUP="rg-aifoundry-20260203"
DEFAULT_LOCATION="eastus"
DEFAULT_STORAGE_ACCOUNT="staifoundry20260203"
DEFAULT_SEARCH_SERVICE="srch-aifoundry-7kkykgt6"
DEFAULT_AI_HUB="aihub-foundry"
DEFAULT_AI_PROJECT="aiproj-agents"
DEFAULT_CONTAINER_NAME="documents"

# 사용자 입력 받기 (또는 기본값 사용)
RESOURCE_GROUP=$(get_input "Resource Group 이름" "$DEFAULT_RESOURCE_GROUP")
LOCATION=$(get_input "Azure 리전" "$DEFAULT_LOCATION")
STORAGE_ACCOUNT=$(get_input "Storage Account 이름" "$DEFAULT_STORAGE_ACCOUNT")
SEARCH_SERVICE=$(get_input "AI Search Service 이름" "$DEFAULT_SEARCH_SERVICE")
AI_HUB=$(get_input "AI Hub 이름" "$DEFAULT_AI_HUB")
AI_PROJECT=$(get_input "AI Project 이름" "$DEFAULT_AI_PROJECT")
CONTAINER_NAME=$(get_input "Blob Container 이름" "$DEFAULT_CONTAINER_NAME")

print_success "환경 변수 설정 완료"
echo ""
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Search Service: $SEARCH_SERVICE"
echo "  AI Hub: $AI_HUB"
echo "  AI Project: $AI_PROJECT"
echo "  Container: $CONTAINER_NAME"

# =============================================================================
# Step 2: Azure 연결 확인
# =============================================================================

print_section "2/8" "Azure 연결 확인"

# Azure CLI 설치 확인
if ! command -v az &> /dev/null; then
    print_error "Azure CLI가 설치되어 있지 않습니다."
    print_info "Azure CLI 설치: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

print_success "Azure CLI 설치 확인"

# Azure 로그인 확인
if ! az account show &> /dev/null; then
    print_warning "Azure에 로그인되어 있지 않습니다. 로그인을 진행합니다..."
    az login
fi

# 현재 구독 확인
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_success "Azure 구독 확인: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# =============================================================================
# Step 3: 리소스 존재 확인
# =============================================================================

print_section "3/8" "리소스 존재 확인"

# Resource Group 확인
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_success "Resource Group 존재: $RESOURCE_GROUP"
else
    print_error "Resource Group이 존재하지 않습니다: $RESOURCE_GROUP"
    print_info "Terraform 배포를 먼저 실행하세요."
    exit 1
fi

# Storage Account 확인
if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_success "Storage Account 존재: $STORAGE_ACCOUNT"
else
    print_error "Storage Account가 존재하지 않습니다: $STORAGE_ACCOUNT"
    exit 1
fi

# AI Search 확인
if az search service show --name "$SEARCH_SERVICE" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_success "AI Search Service 존재: $SEARCH_SERVICE"
else
    print_error "AI Search Service가 존재하지 않습니다: $SEARCH_SERVICE"
    exit 1
fi

# =============================================================================
# Step 4: Private Endpoint DNS 테스트
# =============================================================================

print_section "4/8" "Private Endpoint DNS 해석 테스트"

# Storage Blob DNS 테스트
STORAGE_BLOB_FQDN="${STORAGE_ACCOUNT}.blob.core.windows.net"
echo -e "${CYAN}→ Testing: $STORAGE_BLOB_FQDN${NC}"
if host "$STORAGE_BLOB_FQDN" | grep -q "10.0.1"; then
    print_success "Storage Blob Private Endpoint DNS 정상 (Private IP)"
else
    print_warning "Storage Blob이 Public IP로 해석됩니다. Private DNS Zone 설정을 확인하세요."
fi

# AI Search DNS 테스트
SEARCH_FQDN="${SEARCH_SERVICE}.search.windows.net"
echo -e "${CYAN}→ Testing: $SEARCH_FQDN${NC}"
if host "$SEARCH_FQDN" | grep -q "10.0.1"; then
    print_success "AI Search Private Endpoint DNS 정상 (Private IP)"
else
    print_warning "AI Search가 Public IP로 해석됩니다. Private DNS Zone 설정을 확인하세요."
fi

# =============================================================================
# Step 5: Storage Container 생성
# =============================================================================

print_section "5/8" "Storage Container 생성"

# Container 생성 (이미 존재하면 스킵)
if az storage container exists \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login \
    --query exists -o tsv | grep -q "true"; then
    print_info "Container가 이미 존재합니다: $CONTAINER_NAME"
else
    if run_command "Container 생성" \
        az storage container create \
            --name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT" \
            --auth-mode login; then
        print_success "Container 생성 완료: $CONTAINER_NAME"
    else
        print_error "Container 생성 실패"
        exit 1
    fi
fi

# =============================================================================
# Step 6: 테스트 문서 생성 및 업로드
# =============================================================================

print_section "6/8" "테스트 문서 생성 및 업로드"

# 임시 디렉토리 생성
TEMP_DIR="$(mktemp -d)/test_documents"
mkdir -p "$TEMP_DIR"

print_info "임시 디렉토리: $TEMP_DIR"

# 테스트 문서 생성 (텍스트 파일)
cat > "$TEMP_DIR/AI_Foundry_소개.txt" << 'EOF'
Azure AI Foundry 플랫폼 소개

Azure AI Foundry는 Microsoft의 통합 AI 개발 플랫폼으로, 
다음과 같은 주요 기능을 제공합니다:

1. 프라이빗 네트워킹 지원
   - Private Endpoints를 통한 안전한 접근
   - VNet 통합으로 네트워크 격리
   - Azure Bastion을 통한 보안 접속

2. AI 모델 통합
   - Azure OpenAI GPT-4o
   - Text Embedding Ada-002
   - 커스텀 모델 배포

3. RAG 패턴 지원
   - Azure AI Search 통합
   - 문서 인덱싱 및 검색
   - Semantic Search

4. 멀티 리전 구성
   - East US: AI Foundry Hub/Project
   - Korea Central: Jumpbox 및 Bastion

이 플랫폼을 사용하면 엔터프라이즈급 AI 솔루션을 
안전하고 효율적으로 구축할 수 있습니다.
EOF

cat > "$TEMP_DIR/RAG_패턴_가이드.txt" << 'EOF'
RAG 패턴 구현 가이드

RAG (Retrieval-Augmented Generation)는 
검색 기반 AI 응답 생성 패턴입니다.

구성 요소:
1. 문서 저장소: Azure Blob Storage
2. 검색 엔진: Azure AI Search
3. 임베딩 모델: text-embedding-ada-002
4. 생성 모델: GPT-4o

구현 단계:
1. 문서를 Blob Storage에 업로드
2. AI Search 인덱서로 문서 인덱싱
3. 사용자 질문을 임베딩으로 변환
4. 유사 문서 검색
5. 검색 결과를 컨텍스트로 GPT-4o 호출
6. 최종 응답 생성

이 패턴을 사용하면 최신 정보를 기반으로
정확한 AI 응답을 생성할 수 있습니다.
EOF

cat > "$TEMP_DIR/보안_가이드.txt" << 'EOF'
프라이빗 네트워킹 보안 가이드

Zero Trust 보안 원칙:
1. 모든 서비스는 Private Endpoint로만 접근
2. Public Network Access 비활성화
3. NSG로 트래픽 제어
4. Managed Identity로 인증

네트워크 보안 설정:
- VNet Peering: Korea Central ↔ East US
- Private DNS Zones: 10개 DNS Zone 구성
- NSG Rules: 최소 권한 원칙
- Azure Bastion: Jumpbox 보안 접속

RBAC 권한 설정:
- Storage Blob Data Contributor
- Cognitive Services User
- Key Vault Secrets Officer
- Search Index Data Contributor

이러한 보안 설정을 통해 엔터프라이즈급
보안 수준을 유지할 수 있습니다.
EOF

print_success "테스트 문서 생성 완료 (3개)"

# 문서 업로드
print_info "문서 업로드 중..."
for file in "$TEMP_DIR"/*.txt; do
    filename=$(basename "$file")
    echo -e "${CYAN}→ 업로드: $filename${NC}"
    
    if az storage blob upload \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "$CONTAINER_NAME" \
        --name "$filename" \
        --file "$file" \
        --auth-mode login \
        --overwrite &> /dev/null; then
        print_success "$filename 업로드 완료"
    else
        print_warning "$filename 업로드 실패 (이미 존재하거나 권한 부족)"
    fi
done

# 업로드된 파일 확인
print_info "업로드된 파일 목록:"
az storage blob list \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER_NAME" \
    --auth-mode login \
    --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" \
    --output table

# =============================================================================
# Step 7: AI Search 인덱스 생성
# =============================================================================

print_section "7/8" "AI Search 인덱스 생성"

INDEX_NAME="aifoundry-docs-index"
SEARCH_ENDPOINT="https://${SEARCH_SERVICE}.search.windows.net"

print_info "Search Endpoint: $SEARCH_ENDPOINT"
print_info "Index Name: $INDEX_NAME"

# 인덱스 스키마 정의
INDEX_SCHEMA=$(cat <<EOF
{
    "name": "$INDEX_NAME",
    "fields": [
        {
            "name": "id",
            "type": "Edm.String",
            "key": true,
            "filterable": true
        },
        {
            "name": "content",
            "type": "Edm.String",
            "searchable": true,
            "analyzer": "ko.microsoft"
        },
        {
            "name": "title",
            "type": "Edm.String",
            "searchable": true,
            "filterable": true,
            "sortable": true
        },
        {
            "name": "metadata_storage_name",
            "type": "Edm.String",
            "searchable": true,
            "filterable": true
        },
        {
            "name": "metadata_storage_path",
            "type": "Edm.String",
            "filterable": true
        }
    ]
}
EOF
)

# 인덱스 생성 (Azure AD 인증 사용)
print_info "인덱스 생성 중..."
if az rest \
    --method PUT \
    --url "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
    --headers "Content-Type=application/json" \
    --body "$INDEX_SCHEMA" \
    --resource "https://search.azure.com" &> /dev/null; then
    print_success "인덱스 생성 완료: $INDEX_NAME"
else
    print_warning "인덱스 생성 실패 (이미 존재하거나 권한 부족)"
fi

# Data Source 생성
DATASOURCE_NAME="aifoundry-blob-datasource"
STORAGE_RESOURCE_ID=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query id -o tsv)

DATASOURCE_SCHEMA=$(cat <<EOF
{
    "name": "$DATASOURCE_NAME",
    "type": "azureblob",
    "credentials": {
        "connectionString": "ResourceId=$STORAGE_RESOURCE_ID;"
    },
    "container": {
        "name": "$CONTAINER_NAME"
    },
    "dataChangeDetectionPolicy": {
        "@odata.type": "#Microsoft.Azure.Search.HighWaterMarkChangeDetectionPolicy",
        "highWaterMarkColumnName": "_ts"
    }
}
EOF
)

print_info "Data Source 생성 중..."
if az rest \
    --method PUT \
    --url "$SEARCH_ENDPOINT/datasources/$DATASOURCE_NAME?api-version=2024-07-01" \
    --headers "Content-Type=application/json" \
    --body "$DATASOURCE_SCHEMA" \
    --resource "https://search.azure.com" &> /dev/null; then
    print_success "Data Source 생성 완료: $DATASOURCE_NAME"
else
    print_warning "Data Source 생성 실패 (이미 존재하거나 권한 부족)"
fi

# Indexer 생성
INDEXER_NAME="aifoundry-docs-indexer"
INDEXER_SCHEMA=$(cat <<EOF
{
    "name": "$INDEXER_NAME",
    "dataSourceName": "$DATASOURCE_NAME",
    "targetIndexName": "$INDEX_NAME",
    "schedule": {
        "interval": "PT2H"
    },
    "parameters": {
        "configuration": {
            "parsingMode": "text"
        }
    },
    "fieldMappings": [
        {
            "sourceFieldName": "metadata_storage_name",
            "targetFieldName": "title"
        }
    ]
}
EOF
)

print_info "Indexer 생성 중..."
if az rest \
    --method PUT \
    --url "$SEARCH_ENDPOINT/indexers/$INDEXER_NAME?api-version=2024-07-01" \
    --headers "Content-Type=application/json" \
    --body "$INDEXER_SCHEMA" \
    --resource "https://search.azure.com" &> /dev/null; then
    print_success "Indexer 생성 완료: $INDEXER_NAME"
else
    print_warning "Indexer 생성 실패 (이미 존재하거나 권한 부족)"
fi

# Indexer 실행
print_info "Indexer 실행 중..."
if az rest \
    --method POST \
    --url "$SEARCH_ENDPOINT/indexers/$INDEXER_NAME/run?api-version=2024-07-01" \
    --resource "https://search.azure.com" &> /dev/null; then
    print_success "Indexer 실행 완료"
    print_info "인덱싱 완료까지 1-2분 소요됩니다."
else
    print_warning "Indexer 실행 실패"
fi

# =============================================================================
# Step 8: AI Foundry 연결 테스트
# =============================================================================

print_section "8/8" "AI Foundry 연결 테스트"

# AI Hub 존재 확인
print_info "AI Hub 확인 중..."
if az ml workspace show \
    --name "$AI_HUB" \
    --resource-group "$RESOURCE_GROUP" \
    --query name -o tsv &> /dev/null; then
    print_success "AI Hub 존재: $AI_HUB"
else
    print_error "AI Hub가 존재하지 않습니다: $AI_HUB"
    exit 1
fi

# Azure OpenAI 엔드포인트 확인
OPENAI_ACCOUNT=$(az cognitiveservices account list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?kind=='OpenAI'].name" -o tsv | head -1)

if [ -n "$OPENAI_ACCOUNT" ]; then
    OPENAI_ENDPOINT=$(az cognitiveservices account show \
        --name "$OPENAI_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --query properties.endpoint -o tsv)
    print_success "Azure OpenAI 엔드포인트: $OPENAI_ENDPOINT"
else
    print_warning "Azure OpenAI 계정을 찾을 수 없습니다."
fi

# =============================================================================
# 예제 코드 생성
# =============================================================================

print_header "예제 코드 생성"

# CURL 예제 저장
EXAMPLE_DIR="$HOME/ai-foundry-examples"
mkdir -p "$EXAMPLE_DIR"

print_info "예제 코드 저장 위치: $EXAMPLE_DIR"

# 1. AI Search 검색 예제
cat > "$EXAMPLE_DIR/search-test.sh" << EOF
#!/bin/bash
# AI Search 검색 테스트

SEARCH_ENDPOINT="https://${SEARCH_SERVICE}.search.windows.net"
INDEX_NAME="$INDEX_NAME"

echo "AI Search 검색 테스트..."

# Azure AD 토큰 가져오기
TOKEN=\$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)

# 검색 실행
curl -X POST "\$SEARCH_ENDPOINT/indexes/\$INDEX_NAME/docs/search?api-version=2024-07-01" \\
    -H "Authorization: Bearer \$TOKEN" \\
    -H "Content-Type: application/json" \\
    -d '{
        "search": "AI Foundry",
        "top": 3,
        "select": "title, content"
    }' | jq '.'

echo ""
echo "검색 완료!"
EOF

chmod +x "$EXAMPLE_DIR/search-test.sh"
print_success "AI Search 검색 예제: $EXAMPLE_DIR/search-test.sh"

# 2. Blob 파일 업로드 예제
cat > "$EXAMPLE_DIR/upload-document.sh" << EOF
#!/bin/bash
# Blob Storage 파일 업로드 예제

STORAGE_ACCOUNT="$STORAGE_ACCOUNT"
CONTAINER_NAME="$CONTAINER_NAME"

# 사용법 확인
if [ \$# -eq 0 ]; then
    echo "사용법: ./upload-document.sh <파일경로>"
    exit 1
fi

FILE_PATH="\$1"
FILE_NAME=\$(basename "\$FILE_PATH")

echo "파일 업로드 중: \$FILE_NAME"

# 파일 업로드
az storage blob upload \\
    --account-name "\$STORAGE_ACCOUNT" \\
    --container-name "\$CONTAINER_NAME" \\
    --name "\$FILE_NAME" \\
    --file "\$FILE_PATH" \\
    --auth-mode login \\
    --overwrite

echo "업로드 완료: \$FILE_NAME"

# Indexer 수동 실행
echo "Indexer 실행 중..."
SEARCH_ENDPOINT="https://${SEARCH_SERVICE}.search.windows.net"
TOKEN=\$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)

curl -X POST "\$SEARCH_ENDPOINT/indexers/${INDEXER_NAME}/run?api-version=2024-07-01" \\
    -H "Authorization: Bearer \$TOKEN"

echo ""
echo "완료! 1-2분 후 AI Foundry Playground에서 문서를 검색할 수 있습니다."
EOF

chmod +x "$EXAMPLE_DIR/upload-document.sh"
print_success "파일 업로드 예제: $EXAMPLE_DIR/upload-document.sh"

# 3. Python 예제 (AI Foundry Playground 스타일)
cat > "$EXAMPLE_DIR/playground-example.py" << 'EOF'
#!/usr/bin/env python3
"""
AI Foundry Playground 스타일 예제 코드

이 코드는 AI Foundry Playground에서 생성된 코드와 동일한 형태로
Azure OpenAI + AI Search RAG 패턴을 구현합니다.
"""

import os
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from openai import AzureOpenAI

# 환경 변수 설정
SEARCH_ENDPOINT = "https://SEARCH_SERVICE.search.windows.net"
SEARCH_INDEX = "INDEX_NAME"
OPENAI_ENDPOINT = "https://OPENAI_ACCOUNT.openai.azure.com"
OPENAI_DEPLOYMENT = "gpt-4o"

def search_documents(query: str, top_k: int = 3):
    """AI Search에서 문서 검색"""
    credential = DefaultAzureCredential()
    search_client = SearchClient(
        endpoint=SEARCH_ENDPOINT,
        index_name=SEARCH_INDEX,
        credential=credential
    )
    
    results = search_client.search(
        search_text=query,
        top=top_k,
        select=["title", "content"]
    )
    
    documents = []
    for result in results:
        documents.append({
            "title": result.get("title", ""),
            "content": result.get("content", "")
        })
    
    return documents

def generate_response(query: str, documents: list):
    """검색된 문서를 기반으로 GPT-4o 응답 생성"""
    credential = DefaultAzureCredential()
    client = AzureOpenAI(
        azure_endpoint=OPENAI_ENDPOINT,
        api_version="2024-10-21",
        azure_ad_token_provider=credential.get_token("https://cognitiveservices.azure.com/.default")
    )
    
    # 문서를 컨텍스트로 결합
    context = "\n\n".join([
        f"[{doc['title']}]\n{doc['content']}"
        for doc in documents
    ])
    
    # System prompt (RAG 패턴)
    system_prompt = f"""당신은 제공된 문서를 기반으로 정확한 답변을 제공하는 AI 어시스턴트입니다.
다음 문서를 참고하여 사용자의 질문에 답변하세요:

{context}

문서에 정보가 없으면 "제공된 문서에서 해당 정보를 찾을 수 없습니다"라고 답변하세요."""
    
    # GPT-4o 호출
    response = client.chat.completions.create(
        model=OPENAI_DEPLOYMENT,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": query}
        ],
        temperature=0.7,
        max_tokens=800
    )
    
    return response.choices[0].message.content

def main():
    """메인 함수"""
    print("=" * 60)
    print("AI Foundry RAG 패턴 예제")
    print("=" * 60)
    
    # 사용자 질문
    query = input("\n질문을 입력하세요: ")
    
    # 1. 문서 검색
    print(f"\n[1/2] AI Search에서 문서 검색 중: '{query}'")
    documents = search_documents(query)
    print(f"검색 결과: {len(documents)}개 문서")
    
    for i, doc in enumerate(documents, 1):
        print(f"  {i}. {doc['title']}")
    
    # 2. GPT-4o 응답 생성
    print("\n[2/2] GPT-4o로 응답 생성 중...")
    answer = generate_response(query, documents)
    
    # 결과 출력
    print("\n" + "=" * 60)
    print("답변:")
    print("=" * 60)
    print(answer)
    print("\n" + "=" * 60)

if __name__ == "__main__":
    main()
EOF

# 환경 변수 치환
if [ -n "$OPENAI_ACCOUNT" ]; then
    sed -i "s/SEARCH_SERVICE/${SEARCH_SERVICE}/g" "$EXAMPLE_DIR/playground-example.py"
    sed -i "s/INDEX_NAME/${INDEX_NAME}/g" "$EXAMPLE_DIR/playground-example.py"
    sed -i "s/OPENAI_ACCOUNT/${OPENAI_ACCOUNT}/g" "$EXAMPLE_DIR/playground-example.py"
fi

chmod +x "$EXAMPLE_DIR/playground-example.py"
print_success "Python 예제: $EXAMPLE_DIR/playground-example.py"

# =============================================================================
# 배포 완료 요약
# =============================================================================

print_header "배포 완료!"

echo -e "\n${GREEN}✓ 모든 작업이 완료되었습니다!${NC}\n"

echo -e "${MAGENTA}배포된 리소스:${NC}"
echo "  - Resource Group: $RESOURCE_GROUP"
echo "  - Storage Account: $STORAGE_ACCOUNT"
echo "  - Container: $CONTAINER_NAME"
echo "  - AI Search: $SEARCH_SERVICE"
echo "  - Index: $INDEX_NAME"
echo "  - Indexer: $INDEXER_NAME"
echo "  - AI Hub: $AI_HUB"
echo "  - AI Project: $AI_PROJECT"

echo -e "\n${MAGENTA}생성된 파일:${NC}"
echo "  - 테스트 문서: 3개 (Blob Storage에 업로드됨)"
echo "  - 예제 스크립트: $EXAMPLE_DIR/"
echo "    • search-test.sh - AI Search 검색 테스트"
echo "    • upload-document.sh - 문서 업로드"
echo "    • playground-example.py - Python RAG 예제"

echo -e "\n${MAGENTA}다음 단계:${NC}"
echo "  1. AI Foundry Portal 접속: https://ai.azure.com"
echo "  2. Hub 선택: $AI_HUB"
echo "  3. Project 선택: $AI_PROJECT"
echo "  4. Playground → Chat 탭"
echo "  5. 'Add your data' → Azure AI Search 선택"
echo "  6. Index: $INDEX_NAME 선택"
echo "  7. 테스트 질문 입력:"
echo "     • Azure AI Foundry의 주요 기능은?"
echo "     • RAG 패턴의 구성 요소는?"
echo "     • 프라이빗 네트워킹 보안 설정은?"

echo -e "\n${MAGENTA}예제 실행 방법:${NC}"
echo "  # AI Search 검색 테스트"
echo "  $ cd $EXAMPLE_DIR"
echo "  $ ./search-test.sh"
echo ""
echo "  # 새 문서 업로드"
echo "  $ ./upload-document.sh /path/to/document.txt"
echo ""
echo "  # Python RAG 예제"
echo "  $ python3 playground-example.py"

echo -e "\n${CYAN}로그 파일: $(pwd)/deploy.log${NC}"
echo -e "${GREEN}배포 스크립트 실행이 완료되었습니다.${NC}\n"
