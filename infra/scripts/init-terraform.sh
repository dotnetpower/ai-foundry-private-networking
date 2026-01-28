#!/bin/bash
set -e

# AI Foundry Private Networking - Terraform 초기화 스크립트
# 사용법: ./init-terraform.sh [local|remote]

echo "=========================================="
echo "Terraform 초기화"
echo "=========================================="

# 인자 확인
BACKEND_TYPE="${1:-local}"

# 프로젝트 루트로 이동
cd "$(dirname "$0")/.."

if [ "$BACKEND_TYPE" = "remote" ]; then
  echo ""
  echo "모드: 원격 Backend (Azure Storage)"
  echo ""
  
  # backend 블록이 주석 처리되어 있는지 확인
  if grep -q "^  # backend \"azurerm\"" main.tf; then
    echo "경고: main.tf에서 backend 블록이 주석 처리되어 있습니다."
    echo "원격 backend를 사용하려면 backend 블록의 주석을 해제하세요."
    echo ""
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "취소되었습니다."
      exit 1
    fi
  fi
  
  # RBAC 권한 전파 대기
  echo "RBAC 권한 전파를 기다리는 중 (10초)..."
  sleep 10
  
  # 원격 backend로 초기화
  echo ""
  echo "Terraform 초기화 실행 중..."
  terraform init \
    -backend-config="environments/dev/backend.tfvars" \
    -reconfigure
    
elif [ "$BACKEND_TYPE" = "local" ]; then
  echo ""
  echo "모드: 로컬 Backend"
  echo ""
  
  # backend 블록이 활성화되어 있는지 확인
  if ! grep -q "^  # backend \"azurerm\"" main.tf; then
    echo "경고: main.tf에서 backend 블록이 활성화되어 있습니다."
    echo "로컬 backend를 사용하려면 backend 블록을 주석 처리하세요."
    echo ""
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "취소되었습니다."
      exit 1
    fi
  fi
  
  # 로컬 backend로 초기화
  echo ""
  echo "Terraform 초기화 실행 중..."
  terraform init
  
else
  echo "오류: 잘못된 인자입니다."
  echo "사용법: $0 [local|remote]"
  echo ""
  echo "  local  - 로컬 backend 사용 (기본값)"
  echo "  remote - Azure Storage backend 사용"
  exit 1
fi

# 완료
echo ""
echo "=========================================="
echo "✓ Terraform 초기화 완료!"
echo "=========================================="
echo ""
echo "다음 단계:"
echo "  1. terraform fmt -recursive"
echo "  2. terraform validate"
echo "  3. terraform plan -var-file='environments/dev/terraform.tfvars'"
echo ""
