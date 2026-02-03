# 보안 모범 사례

## 개요

이 문서는 AI Foundry Private Networking 인프라의 보안 모범 사례를 설명합니다.

## 자격 증명 관리

### Jumpbox 패스워드 설정

**중요**: `variables.tf`에는 보안상 기본 패스워드가 제거되었습니다. 다음 방법 중 하나로 안전하게 패스워드를 설정하세요.

#### 방법 1: 환경 변수 사용 (권장)

```bash
export TF_VAR_jumpbox_admin_username="azureuser"
export TF_VAR_jumpbox_admin_password="YourVerySecurePassword!2024"

cd infra
terraform apply -var-file="environments/dev/terraform.tfvars"
```

#### 방법 2: 로컬 tfvars 파일 사용

```bash
cd infra/environments/dev
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 파일 편집 (Git에 커밋되지 않음)
echo 'jumpbox_admin_username = "azureuser"' >> terraform.tfvars
echo 'jumpbox_admin_password = "YourVerySecurePassword!2024"' >> terraform.tfvars

cd ../..
terraform apply -var-file="environments/dev/terraform.tfvars"
```

#### 방법 3: Azure Key Vault 참조 (프로덕션 권장)

```bash
# Key Vault에 비밀 저장
az keyvault secret set \
  --vault-name <your-keyvault-name> \
  --name jumpbox-admin-password \
  --value "YourVerySecurePassword!2024"

# Terraform에서 Data Source로 참조
# data "azurerm_key_vault_secret" "jumpbox_password" {
#   name         = "jumpbox-admin-password"
#   key_vault_id = azurerm_key_vault.this.id
# }
```

### 패스워드 복잡성 요구사항

Azure Windows VM 패스워드는 다음 요구사항을 충족해야 합니다:

- **최소 길이**: 12자 이상 (권장: 16자 이상)
- **복잡성**: 다음 4가지 중 3가지 포함
  - 소문자 (a-z)
  - 대문자 (A-Z)
  - 숫자 (0-9)
  - 특수문자 (!@#$%^&* 등)
- **금지**: 사용자 이름 포함, "password", "admin" 등 일반적인 단어

**예시**: `MySecure!Jumpbox2024#KRC`

## SSH 키 인증 (Linux VM 권장)

### SSH 키 생성

```bash
# ED25519 키 생성 (권장)
ssh-keygen -t ed25519 -C "jumpbox-krc" -f ~/.ssh/jumpbox-krc

# 또는 RSA 키 (4096 비트)
ssh-keygen -t rsa -b 4096 -C "jumpbox-krc" -f ~/.ssh/jumpbox-krc
```

### Terraform에서 SSH 키 사용

```terraform
# infra/modules/jumpbox-krc/main.tf 수정
resource "azurerm_linux_virtual_machine" "jumpbox" {
  # ... 기타 설정 ...
  
  disable_password_authentication = true  # 패스워드 인증 비활성화
  
  admin_ssh_key {
    username   = var.jumpbox_admin_username
    public_key = file("~/.ssh/jumpbox-krc.pub")
  }
  
  # ... 기타 설정 ...
}
```

### SSH 접속 (Bastion Native Client)

```bash
# Azure CLI를 통한 SSH Bastion 연결
az network bastion ssh \
  --name bastion-jumpbox-krc \
  --resource-group rg-aifoundry-20260128 \
  --target-resource-id <linux-vm-resource-id> \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/jumpbox-krc
```

## 네트워크 보안

### NSG 규칙 최소화

현재 배포된 NSG 구성:

#### Korea Central Jumpbox (실제 사용)

- ✅ **Inbound**: Bastion 서브넷(10.1.255.0/26)에서만 RDP/SSH 허용
- ✅ **Outbound**: East US VNet(10.0.0.0/16) 및 인터넷 허용

#### East US Jumpbox (미사용, 템플릿)

- ⚠️ **Inbound**: 현재 모든 소스(*) 허용 - 프로덕션 배포 시 Bastion으로 제한 필요

### 프라이빗 엔드포인트 강제

모든 Azure 서비스는 프라이빗 엔드포인트를 통해서만 접근:

```terraform
# 예시: Storage Account
resource "azurerm_storage_account" "this" {
  # ...
  public_network_access_enabled = false  # 공용 접근 차단
  # ...
}

resource "azurerm_private_endpoint" "storage" {
  # Private Endpoint 구성
}
```

## 비밀 관리

### Terraform State 파일 보호

**중요**: Terraform state 파일에는 민감한 정보가 포함되어 있습니다.

```bash
# 로컬 state 파일 보호
chmod 600 terraform.tfstate

# Azure Storage 백엔드 사용 (권장)
cd infra
./scripts/init-terraform.sh remote
```

### .gitignore 검증

다음 파일들이 `.gitignore`에 포함되어 있는지 확인:

```gitignore
# 민감 정보 포함 파일
*.tfvars
*.tfvars.json
*tfplan*
plan.out
*.plan
*.tfstate
*.tfstate.*

# 예외: 예제 파일은 포함
!*.tfvars.example
```

### Terraform Plan 파일 주의

```bash
# ❌ 잘못된 예: plan 파일을 Git에 커밋
terraform plan -out=plan.out
git add plan.out  # 절대 금지!

# ✅ 올바른 예: plan 파일 사용 후 즉시 삭제
terraform plan -out=plan.out
terraform apply plan.out
rm -f plan.out  # 즉시 삭제
```

**이유**: Terraform plan 파일은 바이너리 형태로 모든 민감한 값(패스워드, API 키, 연결 문자열)을 평문으로 포함합니다.

## Azure Policy 및 거버넌스

### Managed Identity 사용

API 키 대신 Managed Identity를 사용하여 서비스 간 인증:

```terraform
# AI Foundry Hub Identity
resource "azurerm_role_assignment" "hub_to_openai" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_machine_learning_workspace.hub.identity[0].principal_id
}
```

### Azure Policy 적용

구독 또는 리소스 그룹 수준에서 보안 정책 적용:

- ✅ **Public Network Access 차단**: Storage, Key Vault, Cognitive Services
- ✅ **TLS 1.2 이상 강제**: 모든 네트워크 통신
- ✅ **Diagnostic Settings 필수**: 모든 리소스 로깅 활성화
- ✅ **Managed Identity 필수**: VM, App Service 등

## 모니터링 및 감사

### Azure Monitor 로깅

```bash
# NSG Flow Logs 활성화
az network watcher flow-log create \
  --name nsg-flow-log-jumpbox \
  --nsg <nsg-resource-id> \
  --storage-account <storage-account-id> \
  --log-analytics-workspace <workspace-id> \
  --retention 90 \
  --enabled true
```

### Azure Sentinel 통합 (선택)

고급 보안 모니터링을 위해 Azure Sentinel 통합 고려:

- 비정상 로그인 패턴 감지
- 권한 상승 시도 모니터링
- 의심스러운 네트워크 트래픽 경고

## 침투 테스트

### Azure 승인된 침투 테스트

Azure 인프라에 대한 침투 테스트는 사전 알림 없이 수행 가능하나, [Azure 침투 테스트 규칙](https://www.microsoft.com/en-us/msrc/pentest-rules-of-engagement)을 준수해야 합니다.

### 금지된 활동

- ❌ DoS/DDoS 공격
- ❌ 다른 고객의 리소스 대상
- ❌ 피싱 또는 소셜 엔지니어링
- ❌ 물리적 보안 위반 시도

## 정기 보안 점검

### 분기별 체크리스트

- [ ] Jumpbox VM 패스워드 로테이션
- [ ] NSG 규칙 검토 및 최소화
- [ ] 사용하지 않는 Private Endpoint 정리
- [ ] Azure Advisor 보안 권장사항 검토
- [ ] Microsoft Defender for Cloud 경고 확인
- [ ] RBAC 역할 할당 감사
- [ ] Storage Account SAS 토큰 로테이션 (사용 시)

### 월별 체크리스트

- [ ] Azure Update Management로 VM 패치 적용
- [ ] Application Insights 오류 로그 검토
- [ ] Key Vault 액세스 로그 검토
- [ ] 비정상 로그인 활동 검토

## 인시던트 대응

### 보안 침해 의심 시

1. **즉시 격리**: 의심되는 리소스 네트워크 차단
   ```bash
   az vm stop --resource-group <rg> --name <vm-name>
   ```

2. **스냅샷 생성**: 포렌식 분석을 위한 증거 보존
   ```bash
   az snapshot create --resource-group <rg> --source <disk-id> --name incident-snapshot-$(date +%Y%m%d)
   ```

3. **로그 수집**: 모든 관련 로그 백업
   ```bash
   az monitor activity-log list --start-time 2024-01-01T00:00:00Z --query "[?level=='Error' || level=='Critical']"
   ```

4. **패스워드 및 키 로테이션**: 모든 자격 증명 즉시 변경

5. **Azure Support 문의**: 심각한 경우 Azure Security Response Center 연락

## 규정 준수

### GDPR / 개인정보보호법

- ✅ 한국 데이터 센터 사용 (Korea Central 리전)
- ✅ 데이터 암호화 (전송 중: TLS 1.2+, 저장 시: AES-256)
- ✅ 개인정보 최소 수집 원칙
- ✅ 데이터 보존 기간 정책 수립

### 산업별 규정

- **금융권 (ISMS-P, ISO 27001)**: 모든 네트워크 트래픽 로깅, 접근 제어
- **의료 (HIPAA, 의료법)**: PHI 데이터 암호화, 접근 감사
- **공공 (개인정보보호법)**: 행안부 클라우드 보안 인증

## 추가 리소스

- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
- [Azure Well-Architected Framework - Security](https://docs.microsoft.com/azure/architecture/framework/security/)
- [Azure AI Services Security](https://docs.microsoft.com/azure/cognitive-services/security-features)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
