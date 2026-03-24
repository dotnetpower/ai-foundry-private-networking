# 보안 모범 사례

## 개요

이 문서는 AI Foundry Private Networking 인프라의 보안 모범 사례를 설명합니다.

---

## 자격 증명 관리

### Jumpbox 패스워드 설정

**중요**: 파라미터 파일에 패스워드를 직접 포함하지 마세요.

#### 방법 1: 대화형 입력 (권장)

```bash
# 배포 시 패스워드 입력
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters jumpboxAdminPassword='<안전한-비밀번호>'
```

#### 방법 2: 환경 변수 사용

```bash
# 환경 변수 설정
export JUMPBOX_PASSWORD='YourVerySecurePassword!2024'

# 배포 시 참조
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters jumpboxAdminPassword="$JUMPBOX_PASSWORD"
```

#### 방법 3: Azure Key Vault 사용 (프로덕션 권장)

```bash
# Key Vault에 비밀 저장
az keyvault secret set \
  --vault-name <your-keyvault-name> \
  --name jumpbox-admin-password \
  --value "YourVerySecurePassword!2024"
```

### 패스워드 복잡성 요구사항

Azure VM 패스워드는 다음 요구사항을 충족해야 합니다:

- **최소 길이**: 12자 이상 (권장: 16자 이상)
- **복잡성**: 다음 4가지 중 3가지 포함
  - 소문자 (a-z)
  - 대문자 (A-Z)
  - 숫자 (0-9)
  - 특수문자 (!@#$%^&* 등)
- **금지**: 사용자 이름 포함, "password", "admin" 등 일반적인 단어

**예시**: `MySecure!Jumpbox2024#SWC`

---

## SSH 키 인증 (Linux VM 권장)

### SSH 키 생성

```bash
# ED25519 키 생성 (권장)
ssh-keygen -t ed25519 -C "jumpbox-swc" -f ~/.ssh/jumpbox-swc

# 또는 RSA 키 (4096 비트)
ssh-keygen -t rsa -b 4096 -C "jumpbox-swc" -f ~/.ssh/jumpbox-swc
```

### SSH 접속 (Bastion Native Client)

```bash
# Azure CLI를 통한 SSH Bastion 연결
az network bastion ssh \
  --name bastion-aifoundry \
  --resource-group <rg-name> \
  --target-resource-id <linux-vm-resource-id> \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/jumpbox-swc
```

---

## 네트워크 보안

### NSG 규칙 최소화

배포된 NSG 구성:

#### Agent 서브넷 NSG

- **Inbound**: VNet 내부에서 HTTPS(443)만 허용
- **기본 거부**: 모든 다른 인바운드 트래픽 차단

#### Private Endpoint 서브넷 NSG

- **Inbound**: VNet 내부에서 HTTPS(443)만 허용
- **기본 거부**: 모든 다른 인바운드 트래픽 차단

#### Jumpbox 서브넷 NSG

- **Inbound**: Bastion 서브넷에서만 SSH(22)/RDP(3389) 허용
- **Outbound**: VNet 및 인터넷 허용

### 프라이빗 엔드포인트 강제

모든 Azure 서비스는 프라이빗 엔드포인트를 통해서만 접근:

```bicep
// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  // ...
  properties: {
    publicNetworkAccess: 'Disabled'  // 공용 접근 차단
    // ...
  }
}
```

---

## 서비스 간 인증

### Managed Identity 사용

API 키 대신 Managed Identity를 사용하여 서비스 간 AAD 인증:

```bicep
// AI Foundry Account → Storage 역할 할당
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, foundryAccount.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: foundryAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
```

### Connection 인증 유형

| Connection | 인증 방식 | 비고 |
|------------|----------|------|
| Storage | AAD (Managed Identity) | SharedKey 사용 안 함 |
| Cosmos DB | AAD (Managed Identity) | 연결 문자열 사용 안 함 |
| AI Search | AAD (Managed Identity) | API 키 사용 안 함 |

---

## 민감 정보 보호

### .gitignore 설정

다음 파일들이 `.gitignore`에 포함되어 있는지 확인:

```gitignore
# 민감 정보 포함 파일
*.tfvars
*.tfvars.json
*.tfstate
*.tfstate.*
*.bicepparam  # 패스워드 포함 시

# 예외: 예제 파일은 포함
!*.tfvars.example
!*.bicepparam.example
```

### 리소스 삭제 시 주의

Cognitive Services 리소스 삭제 후 반드시 **Purge** 실행:

```bash
# 1. 리소스 그룹 삭제
az group delete --name <rg-name> --yes

# 2. Cognitive Services Purge (필수)
az cognitiveservices account purge \
  --name <foundry-account-name> \
  --resource-group <rg-name> \
  --location swedencentral
```

**이유**: Soft Delete 상태의 리소스에 연결된 서브넷이 "in use" 상태로 남아 재배포 실패

---

## Private DNS 보안

### DNS Zone 구성

| DNS Zone | 용도 | VNet Link |
|----------|------|-----------|
| `privatelink.cognitiveservices.azure.com` | AI Foundry | 필수 |
| `privatelink.openai.azure.com` | OpenAI | 필수 |
| `privatelink.services.ai.azure.com` | AI Services | 필수 |
| `privatelink.search.windows.net` | AI Search | 필수 |
| `privatelink.documents.azure.com` | Cosmos DB | 필수 |
| `privatelink.blob.core.windows.net` | Storage Blob | 필수 |
| `privatelink.file.core.windows.net` | Storage File | 필수 |

### DNS 해석 확인

VNet 내부에서 프라이빗 IP로 해식되는지 확인:

```bash
# Jumpbox에서 실행
nslookup <foundry-account>.cognitiveservices.azure.com
# 기대 결과: 192.168.1.x (프라이빗 IP)
```

---

## 로깅 및 모니터링

### 권장 로그 수집

| 리소스 | 로그 유형 | 용도 |
|--------|----------|------|
| AI Foundry | RequestResponse | API 호출 추적 |
| Storage | StorageRead, StorageWrite | 데이터 접근 감사 |
| NSG | FlowLogs | 네트워크 트래픽 분석 |
| Bastion | BastionAuditLogs | 접근 감사 |

---

## 참고 자료

- [Azure AI Security Best Practices](https://learn.microsoft.com/en-us/azure/ai-services/security-features)
- [Private Link Security](https://learn.microsoft.com/en-us/azure/private-link/private-link-overview)
- [Managed Identity Best Practices](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
