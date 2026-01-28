#!/bin/bash
set -e

# AI Foundry Private Networking - Terraform 검증 스크립트

echo "=========================================="
echo "Terraform 코드 검증"
echo "=========================================="

# 프로젝트 루트로 이동
cd "$(dirname "$0")/.."

# 1. 포맷팅
echo ""
echo "[1/3] 코드 포맷팅 중..."
terraform fmt -recursive
echo "✓ 포맷팅 완료"

# 2. 검증
echo ""
echo "[2/3] 구성 검증 중..."
terraform validate
echo "✓ 검증 완료"

# 3. 계획 (선택적)
echo ""
read -p "[3/3] terraform plan을 실행하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "실행 계획 생성 중..."
  terraform plan -var-file="environments/dev/terraform.tfvars"
fi

# 완료
echo ""
echo "=========================================="
echo "✓ 검증 완료!"
echo "=========================================="
echo ""
