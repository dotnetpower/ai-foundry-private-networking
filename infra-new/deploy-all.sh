#!/bin/bash
# =============================================================================
# deploy-all.sh - 전체 배포 오케스트레이션
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 시간 측정
TOTAL_START=$(date +%s)
declare -A STEP_TIMES

# 로그 파일
LOG_FILE="${SCRIPT_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

# 함수: 로그 출력
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# 함수: 단계 실행
run_step() {
    local step_num=$1
    local step_name=$2
    local script=$3
    
    local step_start=$(date +%s)
    
    log ""
    log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${CYAN} 단계 $step_num: $step_name${NC}"
    log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${YELLOW}시작: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    
    if bash "$script" 2>&1 | tee -a "$LOG_FILE"; then
        local step_end=$(date +%s)
        local step_duration=$((step_end - step_start))
        STEP_TIMES["$step_name"]=$step_duration
        log "${GREEN}✓ $step_name 완료 (${step_duration}초)${NC}"
    else
        log "${RED}✗ $step_name 실패${NC}"
        exit 1
    fi
}

# =============================================================================
# 메인 실행
# =============================================================================

clear
log "${BLUE}"
log "╔═══════════════════════════════════════════════════════════════════╗"
log "║                                                                   ║"
log "║     AI Foundry Standard Agent Setup - 전체 배포                   ║"
log "║                                                                   ║"
log "╚═══════════════════════════════════════════════════════════════════╝"
log "${NC}"
log "시작 시간: $(date '+%Y-%m-%d %H:%M:%S')"
log "로그 파일: $LOG_FILE"

# 설정 파일 확인
if [ ! -f "${SCRIPT_DIR}/config.env" ]; then
    log "${RED}Error: config.env 파일을 찾을 수 없습니다.${NC}"
    log "config.env.example을 복사하여 설정하세요:"
    log "  cp config.env.example config.env"
    exit 1
fi

source "${SCRIPT_DIR}/config.env"

log ""
log "${YELLOW}배포 설정:${NC}"
log "  구독: $SUBSCRIPTION_ID"
log "  리전: $LOCATION"
log "  리소스 그룹: $RESOURCE_GROUP_NAME"
log "  모델: $MODEL_NAME ($MODEL_VERSION)"
log ""

read -p "위 설정으로 배포를 시작하시겠습니까? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log "${YELLOW}배포가 취소되었습니다.${NC}"
    exit 0
fi

# =============================================================================
# 배포 단계 실행
# =============================================================================

run_step 1 "사전 요구사항 확인" "scripts/01-prerequisites.sh"
run_step 2 "VNet 구성" "scripts/02-setup-vnet.sh"
run_step 3 "AI Foundry 배포 (Terraform)" "scripts/03-deploy-ai-foundry.sh"
run_step 4 "테스트 데이터 업로드" "scripts/04-upload-test-data.sh"
run_step 5 "AI Search 인덱스 설정" "scripts/05-setup-ai-search.sh"
run_step 6 "배포 검증" "scripts/06-validate-deployment.sh"

# =============================================================================
# 최종 결과
# =============================================================================

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

log ""
log "${GREEN}"
log "╔═══════════════════════════════════════════════════════════════════╗"
log "║                                                                   ║"
log "║                    🎉 배포 완료! 🎉                               ║"
log "║                                                                   ║"
log "╚═══════════════════════════════════════════════════════════════════╝"
log "${NC}"

log ""
log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${BLUE} 단계별 소요 시간${NC}"
log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for step in "${!STEP_TIMES[@]}"; do
    duration=${STEP_TIMES[$step]}
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    log "  $step: ${minutes}분 ${seconds}초"
done

log ""
log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${GREEN} 총 소요 시간: ${TOTAL_MINUTES}분 ${TOTAL_SECONDS}초${NC}"
log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 배포 결과 저장
cat > "${SCRIPT_DIR}/deployment-report.md" << EOF
# AI Foundry Standard Agent 배포 보고서

## 배포 정보
- **배포 일시**: $(date '+%Y-%m-%d %H:%M:%S')
- **리전**: $LOCATION
- **리소스 그룹**: $RESOURCE_GROUP_NAME
- **총 소요 시간**: ${TOTAL_MINUTES}분 ${TOTAL_SECONDS}초

## 단계별 소요 시간
| 단계 | 소요 시간 |
|------|-----------|
EOF

for step in "${!STEP_TIMES[@]}"; do
    duration=${STEP_TIMES[$step]}
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    echo "| $step | ${minutes}분 ${seconds}초 |" >> "${SCRIPT_DIR}/deployment-report.md"
done

cat >> "${SCRIPT_DIR}/deployment-report.md" << EOF

## 배포된 리소스
- AI Services Account: $(jq -r '.ai_account_name.value' outputs.json 2>/dev/null || echo "N/A")
- AI Project: $(jq -r '.project_name.value' outputs.json 2>/dev/null || echo "N/A")
- Capability Host: $(jq -r '.capability_host_name.value' outputs.json 2>/dev/null || echo "N/A")
- Storage Account: $(jq -r '.storage_account_name.value' outputs.json 2>/dev/null || echo "N/A")
- CosmosDB: $(jq -r '.cosmos_db_name.value' outputs.json 2>/dev/null || echo "N/A")
- AI Search: $(jq -r '.ai_search_name.value' outputs.json 2>/dev/null || echo "N/A")

## 다음 단계
1. https://ai.azure.com 접속
2. 생성된 프로젝트 선택
3. Playground에서 Agent 테스트
4. AI Search 도구 추가하여 RAG 테스트
EOF

log ""
log "${YELLOW}배포 보고서가 생성되었습니다: deployment-report.md${NC}"
log ""
log "${CYAN}다음 단계:${NC}"
log "  1. https://ai.azure.com 접속"
log "  2. 생성된 프로젝트 선택"
log "  3. Playground에서 Agent 테스트"
log "  4. AI Search 도구 추가하여 RAG 테스트"
log ""
