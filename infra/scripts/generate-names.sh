#!/bin/bash
# 리소스 이름 자동 생성 스크립트
set -e

TIMESTAMP=$(date +%Y%m%d%H%M)
SHORT_UUID=$(uuidgen | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')

cat > environments/dev/auto-generated.tfvars <<EOF
# 자동 생성된 리소스 이름 ($(date))
storage_account_name = "st${SHORT_UUID:0:8}"
EOF

echo "생성된 변수 파일:"
cat environments/dev/auto-generated.tfvars
echo ""
echo "배포 시 다음 명령어 사용:"
echo "terraform apply -var-file='environments/dev/terraform.tfvars' -var-file='environments/dev/auto-generated.tfvars'"
