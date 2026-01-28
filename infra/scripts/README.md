# Terraform 자동화 스크립트

이 폴더는 AI Foundry Private Networking 프로젝트의 Terraform 배포를 자동화하는 스크립트를 포함합니다.

> **최종 업데이트**: 2026년 1월 28일

## 스크립트 목록

### 1. deploy.sh (권장)
배포 전체 과정을 자동화합니다.

**사용법:**
```bash
cd infra
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

**실행 단계:**
1. Terraform 포맷팅 확인
2. Terraform 유효성 검증
3. 배포 계획 생성
4. 사용자 확인 후 배포 실행

---

### 2. setup-backend.sh
Terraform state를 저장할 Azure Storage backend를 생성합니다.

**사용법:**
```bash
cd infra
chmod +x scripts/setup-backend.sh
./scripts/setup-backend.sh
```

**생성 리소스:**
- Resource Group: `rg-terraform-state-dev`
- Storage Account: `staifoundrytfstate`
- Blob Container: `tfstate`
- RBAC 권한: Storage Blob Data Contributor

**참고:** 
- 이 스크립트는 한 번만 실행하면 됩니다
- 다른 PC에서 작업할 때는 실행할 필요 없습니다 (이미 생성된 리소스 사용)
- Azure CLI 인증이 필요합니다 (`az login`)

---

### 3. init-terraform.sh
Terraform을 초기화합니다 (로컬 또는 원격 backend).

**사용법:**
```bash
cd infra
chmod +x scripts/init-terraform.sh

# 로컬 backend (기본값)
./scripts/init-terraform.sh local

# 원격 backend (Azure Storage)
./scripts/init-terraform.sh remote
```

**모드:**
- `local`: 로컬 파일 시스템에 state 저장 (테스트/개발용)
- `remote`: Azure Storage에 state 저장 (팀 협업용)

---

### 4. validate-terraform.sh
Terraform 코드를 검증하고 포맷팅합니다.

**사용법:**
```bash
cd infra
chmod +x scripts/validate-terraform.sh
./scripts/validate-terraform.sh
```

**실행 단계:**
1. `terraform fmt -recursive` - 코드 포맷팅
2. `terraform validate` - 구성 검증
3. `terraform plan` - 실행 계획 (선택적)

---

### 5. clean-deploy.sh
기존 리소스를 정리하고 새로 배포합니다.

**사용법:**
```bash
cd infra
chmod +x scripts/clean-deploy.sh
./scripts/clean-deploy.sh
```

**주의**: 모든 기존 리소스가 삭제됩니다!

---

## 전체 워크플로우

### 최초 설정 (한 번만)

```bash
cd infra

# 1. 스크립트 실행 권한 부여
chmod +x scripts/*.sh

# 2. Azure 로그인
az login

# 3. Backend 설정 (원격 backend 사용 시)
./scripts/setup-backend.sh

# 4. Terraform 초기화
./scripts/init-terraform.sh local   # 또는 remote
```

### 일상적인 작업

```bash
cd infra

# 1. 배포 (권장)
./scripts/deploy.sh

# 또는 수동으로
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve

# 2. 정리
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

---

## 다른 PC에서 작업하기

다른 PC에서 동일한 프로젝트를 작업하려면:

```bash
# 1. Git clone
git clone <repository-url>
cd ai-foundry-private-networking/infra

# 2. Azure 로그인
az login

# 3. Terraform 초기화 (backend는 이미 생성되어 있음)
chmod +x scripts/*.sh
./scripts/init-terraform.sh remote

# 4. 작업 시작
./scripts/deploy.sh
```

**참고:** `setup-backend.sh`는 실행하지 마세요. Backend 리소스는 이미 존재합니다.

---

## 문제 해결

### RBAC 권한 오류
```bash
# 현재 사용자에게 권한 재할당
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope $(az storage account show --name staifoundrytfstate --resource-group rg-terraform-state-dev --query id -o tsv)

# 10-30초 대기 후 재시도
./scripts/init-terraform.sh remote
```

### Backend 전환 (로컬 ↔ 원격)
```bash
# 로컬에서 원격으로
terraform init -migrate-state -backend-config="environments/dev/backend.tfvars"

# 원격에서 로컬로
# main.tf에서 backend 블록 주석 처리 후
terraform init -migrate-state
```

### Terraform State 동기화
```bash
terraform refresh -var-file="environments/dev/terraform.tfvars"
```

---

## 현재 배포된 리소스 (2026년 1월 28일)

| 리소스 | 이름 |
|--------|------|
| Resource Group | `rg-aifoundry-20260128` |
| VNet (East US) | `vnet-aifoundry` |
| VNet (Korea Central) | `vnet-jumpbox-krc` |
| Storage Account | `staifoundry20260128` |
| Key Vault | `kv-aif-e8txcj4l` |
| Azure OpenAI | `aoai-aifoundry` |
| AI Search | `srch-aifoundry-7kkykgt6` |
| Windows Jumpbox | `vm-jb-win-krc` (10.1.1.4) |
| Linux Jumpbox | `vm-jumpbox-linux-krc` (10.1.1.5) |
| Bastion | `bastion-jumpbox-krc` |

---

## 주의사항

- **민감 정보**: 스크립트에 비밀번호나 키를 하드코딩하지 마세요
- **State 파일**: `.tfstate` 파일은 절대 Git에 커밋하지 마세요
- **Backend 공유**: 여러 사람이 동시에 같은 state를 수정하지 않도록 주의하세요
- **비용**: 사용하지 않는 리소스는 `terraform destroy`로 제거하세요
