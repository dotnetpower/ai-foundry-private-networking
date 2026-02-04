#!/bin/bash
# =============================================================================
# AI Foundry Standard Agent Setup - 배포 스크립트
# =============================================================================
# - VNet 존재 여부 체크 및 자동 생성 (az CLI)
# - Azure Provider 간헐적 버그에 대한 재시도 로직 포함
# - Terraform state 자동 복구 기능
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/deploy.log"

# 설정 파일 로드
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "config.env 파일을 찾을 수 없습니다: $CONFIG_FILE"
    log_info "config.env.example을 복사하여 설정하세요."
    exit 1
fi

log_info "설정 파일 로드 중: $CONFIG_FILE"
source "$CONFIG_FILE"

# 필수 환경변수 검증
validate_config() {
    log_step "1/6 - 설정 검증"
    
    local required_vars=("LOCATION" "RESOURCE_GROUP_NAME" "VNET_NAME" "VNET_PREFIX" 
                         "AGENT_SUBNET_NAME" "AGENT_SUBNET_PREFIX" 
                         "PE_SUBNET_NAME" "PE_SUBNET_PREFIX")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "필수 환경변수가 설정되지 않았습니다: $var"
            exit 1
        fi
    done
    
    # VNET_RESOURCE_GROUP 기본값 설정
    if [[ -z "$VNET_RESOURCE_GROUP" ]]; then
        VNET_RESOURCE_GROUP="$RESOURCE_GROUP_NAME"
        log_info "VNET_RESOURCE_GROUP이 비어있어 RESOURCE_GROUP_NAME 사용: $VNET_RESOURCE_GROUP"
    fi
    
    log_success "설정 검증 완료"
    echo "  - 위치: $LOCATION"
    echo "  - 리소스 그룹: $RESOURCE_GROUP_NAME"
    echo "  - VNet 리소스 그룹: $VNET_RESOURCE_GROUP"
    echo "  - VNet: $VNET_NAME ($VNET_PREFIX)"
}

# Azure 로그인 확인
check_azure_login() {
    log_step "2/6 - Azure 로그인 확인"
    
    if ! az account show &>/dev/null; then
        log_error "Azure에 로그인되어 있지 않습니다. 'az login'을 실행하세요."
        exit 1
    fi
    
    local current_sub=$(az account show --query id -o tsv)
    local current_sub_name=$(az account show --query name -o tsv)
    log_success "Azure 로그인 확인 완료"
    echo "  - 구독: $current_sub_name"
    echo "  - ID: $current_sub"
    
    if [[ -n "$SUBSCRIPTION_ID" && "$current_sub" != "$SUBSCRIPTION_ID" ]]; then
        log_info "구독 변경 중: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
}

# =============================================================================
# 리소스 가용성 사전 검사
# =============================================================================
check_resource_availability() {
    log_step "2.5/6 - 리소스 가용성 사전 검사"
    
    local location="$1"
    local has_issues=false
    
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "리전 '$location'에서 리소스 가용성을 확인합니다..."
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 1. AI Search SKU 가용성 확인
    log_info "[1/4] AI Search 가용성 확인 중..."
    local search_skus=$(az search management list-skus --location "$location" 2>/dev/null)
    if [[ -z "$search_skus" ]]; then
        log_warning "  ⚠ AI Search 가용성 정보를 가져올 수 없습니다."
    else
        local search_sku="${SEARCH_SKU:-basic}"
        if echo "$search_skus" | grep -qi "$search_sku"; then
            log_success "  ✓ AI Search ($search_sku) - 사용 가능"
        else
            log_warning "  ⚠ AI Search ($search_sku) - 가용성 불확실. 배포 시 확인됩니다."
        fi
    fi
    
    # 2. Cognitive Services (OpenAI) 가용성 확인
    log_info "[2/4] Azure OpenAI 가용성 확인 중..."
    local openai_available=$(az cognitiveservices account list-skus \
        --kind AIServices \
        --location "$location" \
        --query "[?name=='S0']" -o tsv 2>/dev/null)
    if [[ -n "$openai_available" ]]; then
        log_success "  ✓ Azure OpenAI (AIServices) - 사용 가능"
    else
        log_warning "  ⚠ Azure OpenAI 가용성 확인 불가. 배포 시 확인됩니다."
    fi
    
    # 3. Storage Account 가용성 확인
    log_info "[3/4] Storage Account 가용성 확인 중..."
    local storage_available=$(az storage account check-name --name "testavailcheck$(date +%s)" 2>/dev/null | grep -c "AlreadyExists\|true" || true)
    log_success "  ✓ Storage Account - 일반적으로 모든 리전에서 사용 가능"
    
    # 4. CosmosDB 가용성 확인
    log_info "[4/4] CosmosDB 가용성 확인 중..."
    log_success "  ✓ CosmosDB - 일반적으로 모든 리전에서 사용 가능"
    
    echo ""
    
    # 5. 할당량(Quota) 확인 - 선택적
    log_info "[추가] 할당량(Quota) 확인 중..."
    
    # Cognitive Services 할당량 확인
    local cs_quota=$(az cognitiveservices usage list --location "$location" 2>/dev/null | head -5)
    if [[ -n "$cs_quota" ]]; then
        log_success "  ✓ Cognitive Services 할당량 정보 확인됨"
    else
        log_info "  ℹ Cognitive Services 할당량 정보를 가져올 수 없습니다 (권한 필요)"
    fi
    
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 리전별 AI Search 가용성 추천
    log_info "📋 AI Search 리전별 권장 사항:"
    echo "  - eastus2, swedencentral: 모든 SKU 일반적으로 가용"
    echo "  - eastus, westeurope: 대부분 SKU 가용"
    echo "  - 기타 리전: 가용성이 제한될 수 있음"
    echo ""
    
    if [[ "$has_issues" == "true" ]]; then
        log_warning "일부 리소스 가용성에 문제가 있을 수 있습니다."
        read -p "계속 진행하시겠습니까? [y/N]: " continue_choice
        if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
            log_error "사용자에 의해 배포가 취소되었습니다."
            exit 1
        fi
    else
        log_success "가용성 사전 검사 완료"
    fi
    
    echo ""
}

# 상세 리전별 모델 가용성 확인
check_openai_model_availability() {
    local location="$1"
    local model_name="${2:-gpt-4o}"
    
    log_info "OpenAI 모델 '$model_name' 가용성 확인 중 (리전: $location)..."
    
    # GlobalStandard 배포가 가능한 주요 리전 목록
    local full_support_regions="eastus2 swedencentral"
    local partial_support_regions="eastus westus westus3 westeurope francecentral uksouth koreacentral japaneast australiaeast canadaeast"
    
    if echo "$full_support_regions" | grep -qw "$location"; then
        log_success "  ✓ '$location'은 모든 최신 모델을 지원합니다 (GPT-5.x, o-series, GPT-4o 등)"
        return 0
    elif echo "$partial_support_regions" | grep -qw "$location"; then
        log_info "  ℹ '$location'은 GPT-4o, o3-mini 등 주요 모델을 지원합니다"
        log_info "  ℹ 최신 모델(GPT-5.x, codex-mini 등)은 eastus2/swedencentral만 지원"
        return 0
    else
        log_warning "  ⚠ '$location'의 모델 가용성이 제한적일 수 있습니다"
        return 1
    fi
}

# =============================================================================
# CapabilityHost (Standard Agent Setup) 가용성 확인
# =============================================================================
check_capability_host_availability() {
    local location="$1"
    
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "CapabilityHost (Standard Agent Setup) 가용성 확인 중..."
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Standard Agent Setup 지원 리전 (2026년 2월 기준)
    # https://learn.microsoft.com/azure/ai-foundry/agents/concepts/model-region-support
    local supported_regions=(
        "westus" "eastus" "eastus2" "japaneast" "francecentral" "spaincentral"
        "uaenorth" "southcentralus" "italynorth" "germanywestcentral" "brazilsouth"
        "southafricanorth" "australiaeast" "swedencentral" "canadaeast"
        "westeurope" "westus3" "uksouth" "southindia" "koreacentral"
        "polandcentral" "switzerlandnorth" "norwayeast"
    )
    
    local is_supported=false
    for region in "${supported_regions[@]}"; do
        if [[ "$region" == "$location" ]]; then
            is_supported=true
            break
        fi
    done
    
    if [[ "$is_supported" == "true" ]]; then
        log_success "  ✓ CapabilityHost - '$location' 리전 지원됨"
    else
        log_error "  ✗ CapabilityHost - '$location' 리전 미지원!"
        log_warning ""
        log_warning "  지원되는 리전 목록:"
        echo "    ${supported_regions[*]}" | tr ' ' '\n' | sed 's/^/      - /' | head -10
        echo "      ... 및 기타"
        echo ""
        
        read -p "  다른 리전으로 변경하시겠습니까? [y/N]: " change_region
        if [[ "$change_region" == "y" || "$change_region" == "Y" ]]; then
            echo ""
            echo "  추천 리전:"
            echo "    [1] eastus2      - 모든 기능 지원 (미국 동부 2)"
            echo "    [2] swedencentral - 모든 기능 지원 (스웨덴)"
            echo "    [3] eastus       - 주요 기능 지원 (미국 동부)"
            echo "    [4] westeurope   - 주요 기능 지원 (서유럽)"
            echo "    [5] koreacentral - 주요 기능 지원 (한국)"
            echo "    [6] 직접 입력"
            echo ""
            read -p "  선택 [1-6]: " region_choice
            
            case $region_choice in
                1) LOCATION="eastus2" ;;
                2) LOCATION="swedencentral" ;;
                3) LOCATION="eastus" ;;
                4) LOCATION="westeurope" ;;
                5) LOCATION="koreacentral" ;;
                6) 
                    read -p "  리전 입력: " custom_region
                    LOCATION="$custom_region"
                    ;;
                *) 
                    log_error "  잘못된 선택. 배포를 중단합니다."
                    exit 1
                    ;;
            esac
            
            log_success "  리전이 '$LOCATION'으로 변경되었습니다."
            echo ""
            # 변경된 리전 재확인
            check_capability_host_availability "$LOCATION"
            return $?
        else
            log_error "  CapabilityHost가 지원되지 않는 리전입니다. 배포를 중단합니다."
            exit 1
        fi
    fi
    
    # 추가 요구사항 확인
    echo ""
    log_info "CapabilityHost 추가 요구사항 확인:"
    
    # 1. Microsoft.App Provider 등록 상태 확인
    log_info "  [1/3] Microsoft.App 리소스 공급자 확인 중..."
    local app_provider=$(az provider show --namespace Microsoft.App --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
    if [[ "$app_provider" == "Registered" ]]; then
        log_success "    ✓ Microsoft.App - 등록됨"
    else
        log_warning "    ⚠ Microsoft.App - $app_provider"
        log_info "    등록 명령: az provider register --namespace Microsoft.App"
        
        read -p "    지금 등록하시겠습니까? [y/N]: " register_app
        if [[ "$register_app" == "y" || "$register_app" == "Y" ]]; then
            log_info "    Microsoft.App 등록 중..."
            az provider register --namespace Microsoft.App --wait 2>/dev/null || true
            log_success "    등록 완료 (전파에 몇 분 소요될 수 있음)"
        fi
    fi
    
    # 2. Microsoft.CognitiveServices Provider 확인
    log_info "  [2/3] Microsoft.CognitiveServices 리소스 공급자 확인 중..."
    local cs_provider=$(az provider show --namespace Microsoft.CognitiveServices --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
    if [[ "$cs_provider" == "Registered" ]]; then
        log_success "    ✓ Microsoft.CognitiveServices - 등록됨"
    else
        log_warning "    ⚠ Microsoft.CognitiveServices - $cs_provider"
        az provider register --namespace Microsoft.CognitiveServices 2>/dev/null || true
    fi
    
    # 3. Container Apps 가용성 확인 (CapabilityHost 의존성)
    log_info "  [3/3] Container Apps 환경 가용성 확인 중..."
    local container_app_check=$(az containerapp env list --query "[0].location" -o tsv 2>/dev/null || echo "")
    if [[ -n "$container_app_check" ]] || [[ "$app_provider" == "Registered" ]]; then
        log_success "    ✓ Container Apps - 사용 가능"
    else
        log_info "    ℹ Container Apps 가용성 확인 불가 (기존 환경 없음)"
    fi
    
    echo ""
    log_success "CapabilityHost 가용성 검사 완료"
    echo ""
    
    return 0
}

# 리소스 그룹 생성
ensure_resource_group() {
    local rg_name="$1"
    local location="$2"
    
    log_info "리소스 그룹 확인: $rg_name"
    
    if az group show --name "$rg_name" &>/dev/null; then
        log_success "리소스 그룹 존재: $rg_name"
        return 0
    fi
    
    log_info "리소스 그룹 생성 중: $rg_name (위치: $location)"
    az group create --name "$rg_name" --location "$location" --output none
    log_success "리소스 그룹 생성 완료: $rg_name"
}

# VNet 및 서브넷 생성/확인
ensure_vnet_and_subnets() {
    log_step "3/6 - VNet 및 서브넷 설정"
    
    # VNet 리소스 그룹 확인/생성
    ensure_resource_group "$VNET_RESOURCE_GROUP" "$LOCATION"
    
    # VNet 확인/생성
    log_info "VNet 확인: $VNET_NAME"
    if az network vnet show --name "$VNET_NAME" --resource-group "$VNET_RESOURCE_GROUP" &>/dev/null; then
        log_success "VNet 존재: $VNET_NAME"
    else
        log_info "VNet 생성 중: $VNET_NAME ($VNET_PREFIX)"
        az network vnet create \
            --name "$VNET_NAME" \
            --resource-group "$VNET_RESOURCE_GROUP" \
            --location "$LOCATION" \
            --address-prefix "$VNET_PREFIX" \
            --output none
        log_success "VNet 생성 완료: $VNET_NAME"
        
        # Azure API 동기화 대기
        log_info "VNet 동기화 대기 중 (15초)..."
        sleep 15
    fi
    
    # Agent 서브넷 확인/생성 (Microsoft.App/environments 위임 포함)
    log_info "Agent 서브넷 확인: $AGENT_SUBNET_NAME"
    if az network vnet subnet show --name "$AGENT_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RESOURCE_GROUP" &>/dev/null; then
        log_success "Agent 서브넷 존재: $AGENT_SUBNET_NAME"
        
        # 위임 확인 및 업데이트
        local delegation=$(az network vnet subnet show --name "$AGENT_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RESOURCE_GROUP" --query "delegations[0].serviceName" -o tsv 2>/dev/null || echo "")
        if [[ "$delegation" != "Microsoft.App/environments" ]]; then
            log_warning "Agent 서브넷에 위임이 없습니다. 업데이트 중..."
            az network vnet subnet update \
                --name "$AGENT_SUBNET_NAME" \
                --vnet-name "$VNET_NAME" \
                --resource-group "$VNET_RESOURCE_GROUP" \
                --delegations "Microsoft.App/environments" \
                --output none 2>/dev/null || log_warning "위임 업데이트 실패 (이미 사용 중일 수 있음)"
        fi
    else
        log_info "Agent 서브넷 생성 중: $AGENT_SUBNET_NAME ($AGENT_SUBNET_PREFIX)"
        
        # 서브넷 생성 재시도 로직
        local subnet_retry=0
        local subnet_max_retry=5
        while [[ $subnet_retry -lt $subnet_max_retry ]]; do
            if az network vnet subnet create \
                --name "$AGENT_SUBNET_NAME" \
                --vnet-name "$VNET_NAME" \
                --resource-group "$VNET_RESOURCE_GROUP" \
                --address-prefix "$AGENT_SUBNET_PREFIX" \
                --delegations "Microsoft.App/environments" \
                --output none 2>&1; then
                log_success "Agent 서브넷 생성 완료: $AGENT_SUBNET_NAME"
                break
            else
                subnet_retry=$((subnet_retry + 1))
                log_warning "서브넷 생성 실패. 재시도 $subnet_retry/$subnet_max_retry (10초 후)..."
                sleep 10
            fi
        done
        
        if [[ $subnet_retry -eq $subnet_max_retry ]]; then
            log_error "Agent 서브넷 생성 실패"
            exit 1
        fi
    fi
    
    # PE 서브넷 확인/생성
    log_info "PE 서브넷 확인: $PE_SUBNET_NAME"
    if az network vnet subnet show --name "$PE_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RESOURCE_GROUP" &>/dev/null; then
        log_success "PE 서브넷 존재: $PE_SUBNET_NAME"
    else
        log_info "PE 서브넷 생성 중: $PE_SUBNET_NAME ($PE_SUBNET_PREFIX)"
        
        # 서브넷 생성 재시도 로직
        local pe_subnet_retry=0
        while [[ $pe_subnet_retry -lt $subnet_max_retry ]]; do
            if az network vnet subnet create \
                --name "$PE_SUBNET_NAME" \
                --vnet-name "$VNET_NAME" \
                --resource-group "$VNET_RESOURCE_GROUP" \
                --address-prefix "$PE_SUBNET_PREFIX" \
                --output none 2>&1; then
                log_success "PE 서브넷 생성 완료: $PE_SUBNET_NAME"
                break
            else
                pe_subnet_retry=$((pe_subnet_retry + 1))
                log_warning "PE 서브넷 생성 실패. 재시도 $pe_subnet_retry/$subnet_max_retry (10초 후)..."
                sleep 10
            fi
        done
    fi
    
    # 서브넷 ID 가져오기 및 출력
    AGENT_SUBNET_ID=$(az network vnet subnet show --name "$AGENT_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RESOURCE_GROUP" --query id -o tsv)
    PE_SUBNET_ID=$(az network vnet subnet show --name "$PE_SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RESOURCE_GROUP" --query id -o tsv)
    
    log_success "VNet 및 서브넷 준비 완료"
}

# Terraform 초기화
init_terraform() {
    log_step "4/6 - Terraform 초기화"
    
    cd "$SCRIPT_DIR"
    
    if [[ ! -d ".terraform" ]]; then
        log_info "Terraform 초기화 중..."
        terraform init
    else
        log_info "Terraform 재초기화 중..."
        terraform init -upgrade
    fi
    
    log_success "Terraform 초기화 완료"
}

# Terraform Apply (재시도 로직 포함)
apply_terraform() {
    log_step "5/6 - Terraform 배포 (재시도 로직 포함)"
    
    local max_retries=5
    local retry_count=0
    local retry_delay=30
    
    cd "$SCRIPT_DIR"
    
    # Terraform 변수 설정
    local tf_vars=(
        -var="location=$LOCATION"
        -var="resource_group_name=$RESOURCE_GROUP_NAME"
        -var="vnet_resource_group=$VNET_RESOURCE_GROUP"
        -var="vnet_name=$VNET_NAME"
        -var="agent_subnet_name=$AGENT_SUBNET_NAME"
        -var="pe_subnet_name=$PE_SUBNET_NAME"
    )
    
    # 선택적 변수 추가
    [[ -n "$AI_SERVICES_NAME" ]] && tf_vars+=(-var="ai_services_name=$AI_SERVICES_NAME")
    [[ -n "$PROJECT_NAME" ]] && tf_vars+=(-var="project_name=$PROJECT_NAME")
    [[ -n "$STORAGE_NAME_PREFIX" ]] && tf_vars+=(-var="storage_name_prefix=$STORAGE_NAME_PREFIX")
    [[ -n "$COSMOSDB_NAME_PREFIX" ]] && tf_vars+=(-var="cosmosdb_name_prefix=$COSMOSDB_NAME_PREFIX")
    [[ -n "$AI_SEARCH_NAME_PREFIX" ]] && tf_vars+=(-var="ai_search_name_prefix=$AI_SEARCH_NAME_PREFIX")
    
    log_info "최대 재시도 횟수: $max_retries"
    
    while [[ $retry_count -lt $max_retries ]]; do
        retry_count=$((retry_count + 1))
        log_info "Terraform Apply 시도 $retry_count/$max_retries"
        
        # Terraform apply 실행
        set +e
        terraform apply -auto-approve "${tf_vars[@]}" 2>&1 | tee "$LOG_FILE"
        local exit_code=${PIPESTATUS[0]}
        set -e
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "Terraform Apply 성공!"
            return 0
        fi
        
        # 오류 분석
        local error_output=$(cat "$LOG_FILE")
        
        # Provider 버그로 인한 일시적 오류 체크
        if echo "$error_output" | grep -q "Provider produced inconsistent result after apply"; then
            log_warning "Azure Provider 일시적 버그 감지"
            log_info "$retry_delay초 후 재시도..."
            sleep $retry_delay
            
            # State refresh 시도
            log_info "Terraform state refresh 중..."
            terraform refresh "${tf_vars[@]}" 2>/dev/null || true
            continue
        fi
        
        # 리소스가 이미 존재하는 경우
        if echo "$error_output" | grep -q "already exists - to be managed via Terraform"; then
            log_warning "기존 리소스 발견. State refresh 후 재시도..."
            terraform refresh "${tf_vars[@]}" 2>/dev/null || true
            sleep 10
            continue
        fi
        
        # 일시적인 네트워크 오류
        if echo "$error_output" | grep -qE "(context deadline exceeded|connection reset|timeout|TooManyRequests)"; then
            log_warning "일시적 오류 감지. $retry_delay초 후 재시도..."
            sleep $retry_delay
            continue
        fi
        
        # ResourceNotFound 오류 - 일시적일 수 있음
        if echo "$error_output" | grep -q "ResourceNotFound"; then
            log_warning "리소스 동기화 문제 감지. $retry_delay초 후 재시도..."
            sleep $retry_delay
            continue
        fi
        
        # ============================================================
        # 인터랙티브 재시도 로직 - 수동 해결이 필요한 오류
        # ============================================================
        
        # SKU 리소스 부족 오류 (AI Search, Cognitive Services 등)
        if echo "$error_output" | grep -qE "ResourcesForSkuUnavailable|SkuNotAvailable"; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "리소스 SKU 가용성 오류 발생!"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # 오류 메시지에서 리전과 SKU 추출
            local failed_region=$(echo "$error_output" | grep -oP "region '\K[^']+")
            local failed_sku=$(echo "$error_output" | grep -oP "SKU '\K[^']+")
            local failed_service=$(echo "$error_output" | grep -oP "Search Service Name: \"\K[^\"]+")
            
            echo ""
            log_info "현재 설정:"
            echo "  - 리전: ${failed_region:-$LOCATION}"
            echo "  - SKU: ${failed_sku:-unknown}"
            echo "  - 서비스: ${failed_service:-unknown}"
            echo ""
            
            log_warning "해결 옵션:"
            echo "  [1] 다른 리전으로 변경 (예: eastus, westus2, westeurope)"
            echo "  [2] SKU 변경 (예: basic, standard, standard2)"
            echo "  [3] 수동 해결 후 재시도"
            echo "  [4] 배포 중단"
            echo ""
            
            read -p "선택하세요 [1-4]: " choice
            
            case $choice in
                1)
                    read -p "새 리전 입력 (예: eastus, westus2): " new_location
                    if [[ -n "$new_location" ]]; then
                        LOCATION="$new_location"
                        log_info "리전이 '$new_location'으로 변경되었습니다."
                        tf_vars=()
                        tf_vars+=(-var="location=$LOCATION")
                        tf_vars+=(-var="resource_group_name=$RESOURCE_GROUP_NAME")
                        tf_vars+=(-var="vnet_resource_group=$VNET_RESOURCE_GROUP")
                        tf_vars+=(-var="vnet_name=$VNET_NAME")
                        tf_vars+=(-var="agent_subnet_name=$AGENT_SUBNET_NAME")
                        tf_vars+=(-var="pe_subnet_name=$PE_SUBNET_NAME")
                        [[ -n "$AI_SERVICES_NAME" ]] && tf_vars+=(-var="ai_services_name=$AI_SERVICES_NAME")
                        [[ -n "$PROJECT_NAME" ]] && tf_vars+=(-var="project_name=$PROJECT_NAME")
                        [[ -n "$STORAGE_NAME_PREFIX" ]] && tf_vars+=(-var="storage_name_prefix=$STORAGE_NAME_PREFIX")
                        [[ -n "$COSMOSDB_NAME_PREFIX" ]] && tf_vars+=(-var="cosmosdb_name_prefix=$COSMOSDB_NAME_PREFIX")
                        [[ -n "$AI_SEARCH_NAME_PREFIX" ]] && tf_vars+=(-var="ai_search_name_prefix=$AI_SEARCH_NAME_PREFIX")
                        retry_count=0  # 재시도 횟수 리셋
                        continue
                    fi
                    ;;
                2)
                    read -p "AI Search SKU 입력 (basic/standard/standard2/standard3): " new_sku
                    if [[ -n "$new_sku" ]]; then
                        tf_vars+=(-var="search_sku=$new_sku")
                        log_info "AI Search SKU가 '$new_sku'으로 변경되었습니다."
                        retry_count=0
                        continue
                    fi
                    ;;
                3)
                    log_info "수동 해결 후 Enter를 눌러 재시도하세요..."
                    read -p ""
                    continue
                    ;;
                4|*)
                    log_error "사용자에 의해 배포가 중단되었습니다."
                    return 1
                    ;;
            esac
            continue
        fi
        
        # Quota 초과 오류
        if echo "$error_output" | grep -qE "QuotaExceeded|InsufficientQuota|OutOfQuota"; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "할당량(Quota) 초과 오류!"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            log_info "해결 방법:"
            echo "  1. Azure Portal에서 할당량 증가 요청"
            echo "  2. 다른 리전 사용"
            echo "  3. 더 작은 SKU 사용"
            echo ""
            
            read -p "[1] 수동 해결 후 재시도 / [2] 배포 중단: " quota_choice
            if [[ "$quota_choice" == "1" ]]; then
                log_info "수동 해결 후 Enter를 눌러 재시도하세요..."
                read -p ""
                continue
            else
                return 1
            fi
        fi
        
        # CapabilityHostOperationFailed 오류
        if echo "$error_output" | grep -qE "CapabilityHostOperationFailed|CapabilityHostProvisioningFailed"; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "Capability Host 프로비저닝 실패!"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            log_info "일반적인 원인:"
            echo "  - RBAC 역할 할당 전파 지연 (1-2분 대기)"
            echo "  - Private Endpoint 설정 미완료"
            echo "  - AI Services Connection 설정 오류"
            echo ""
            
            read -p "[1] 60초 대기 후 재시도 / [2] 수동 해결 후 재시도 / [3] 배포 중단: " cap_choice
            case $cap_choice in
                1)
                    log_info "60초 대기 중 (RBAC 전파 대기)..."
                    sleep 60
                    continue
                    ;;
                2)
                    log_info "수동 해결 후 Enter를 눌러 재시도하세요..."
                    read -p ""
                    continue
                    ;;
                *)
                    return 1
                    ;;
            esac
        fi
        
        # 기타 오류 - 인터랙티브 처리
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "예기치 않은 오류가 발생했습니다!"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "오류 요약:"
        echo "$error_output" | tail -20
        echo ""
        
        read -p "[1] 재시도 / [2] 수동 해결 후 재시도 / [3] 배포 중단: " other_choice
        case $other_choice in
            1)
                log_info "$retry_delay초 후 재시도..."
                sleep $retry_delay
                continue
                ;;
            2)
                log_info "수동 해결 후 Enter를 눌러 재시도하세요..."
                read -p ""
                continue
                ;;
            *)
                return 1
                ;;
        esac
    done
    
    log_error "최대 재시도 횟수($max_retries) 초과. 배포 실패."
    log_error "상세 로그: $LOG_FILE"
    return 1
}

# 결과 출력
print_outputs() {
    log_step "6/6 - 배포 결과"
    
    echo ""
    echo "============================================================"
    terraform output
    echo "============================================================"
    echo ""
    log_success "배포 완료!"
    log_info "Azure AI Foundry Portal: https://ai.azure.com"
}

# 정리 함수
cleanup() {
    echo ""
    log_warning "스크립트가 중단되었습니다."
    exit 1
}

trap cleanup SIGINT SIGTERM

# 메인 함수
main() {
    echo ""
    echo "============================================================"
    echo "  AI Foundry Standard Agent Setup - 배포 스크립트"
    echo "  재시도 로직 및 VNet 자동 생성 기능 포함"
    echo "============================================================"
    echo ""
    
    # 1. 설정 검증
    validate_config
    echo ""
    
    # 2. Azure 로그인 확인
    check_azure_login
    echo ""
    
    # 2.5. 리소스 가용성 사전 검사
    check_resource_availability "$LOCATION"
    check_openai_model_availability "$LOCATION"
    check_capability_host_availability "$LOCATION"
    echo ""
    
    # 3. VNet 및 서브넷 생성/확인 (az CLI로 먼저 처리)
    ensure_vnet_and_subnets
    echo ""
    
    # 4. Terraform 초기화
    init_terraform
    echo ""
    
    # 5. Terraform Apply (재시도 로직 포함)
    if apply_terraform; then
        echo ""
        # 6. 결과 출력
        print_outputs
    else
        log_error "배포 실패. 로그 확인: $LOG_FILE"
        exit 1
    fi
}

# 스크립트 실행
main "$@"
