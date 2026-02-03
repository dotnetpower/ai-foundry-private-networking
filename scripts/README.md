# AI Foundry 스크립트 가이드

이 디렉토리는 AI Foundry 인프라 배포, 구성 및 검증을 위한 스크립트를 포함합니다.

## 📁 스크립트 목록

### 1. Jumpbox 오프라인 배포 스크립트

#### `jumpbox-offline-deploy.sh` (Bash - Linux Jumpbox용)

**용도**: 인터넷 연결이 제한된 Linux Jumpbox에서 AI Foundry 리소스를 구성하고 테스트

**실행 환경**:
- Ubuntu 22.04 LTS
- Azure CLI 설치 필요
- Private Network 접근 가능

**사용법**:
```bash
chmod +x jumpbox-offline-deploy.sh
./jumpbox-offline-deploy.sh
```

**수행 작업**:
1. Azure 연결 확인
2. 리소스 존재 확인 (Resource Group, Storage, Search, AI Hub)
3. Private Endpoint DNS 해석 테스트
4. Storage Container 생성
5. 테스트 문서 생성 및 업로드 (3개 텍스트 파일)
6. AI Search 인덱스/Data Source/Indexer 생성
7. AI Foundry 연결 테스트
8. 예제 코드 생성 (Bash, Python)

**생성되는 파일**:
- `~/ai-foundry-examples/search-test.sh` - AI Search 검색 테스트
- `~/ai-foundry-examples/upload-document.sh` - 문서 업로드 스크립트
- `~/ai-foundry-examples/playground-example.py` - Python RAG 예제

---

#### `jumpbox-offline-deploy.ps1` (PowerShell - Windows Jumpbox용)

**용도**: 인터넷 연결이 제한된 Windows Jumpbox에서 AI Foundry 리소스를 구성하고 테스트

**실행 환경**:
- Windows 11 Pro
- PowerShell 7+
- Azure CLI 설치 필요
- Private Network 접근 가능

**사용법**:
```powershell
.\jumpbox-offline-deploy.ps1
```

**수행 작업**: Bash 버전과 동일

**생성되는 파일**:
- `$HOME\ai-foundry-examples\search-test.ps1` - AI Search 검색 테스트
- `$HOME\ai-foundry-examples\upload-document.ps1` - 문서 업로드 스크립트
- `$HOME\ai-foundry-examples\playground-example.py` - Python RAG 예제

---

### 2. 배포 검증 스크립트

#### `verify-deployment.sh` (Bash)

**용도**: 배포된 AI Foundry 인프라를 자동으로 검증

**실행 환경**:
- Linux/macOS/Windows (Git Bash)
- Azure CLI 설치 필요
- Jumpbox 또는 개발 머신에서 실행 가능

**사용법**:
```bash
chmod +x verify-deployment.sh
./verify-deployment.sh
```

**검증 항목** (7개 테스트):
1. ✅ Azure 연결 및 CLI 확인
2. ✅ 리소스 존재 확인 (Resource Group, Storage, Search, AI Hub)
3. ✅ Private Endpoint DNS 해석 테스트
4. ✅ Storage Account 접근 테스트
5. ✅ AI Search 검색 테스트
6. ✅ Azure OpenAI 모델 배포 확인
7. ✅ End-to-End RAG 패턴 테스트

**출력 예시**:
```
=============================================
  AI Foundry 배포 검증 스크립트
=============================================

[Test 1/7] Azure 연결 확인
✓ PASS: Azure CLI 설치 확인
✓ PASS: Azure 로그인 확인: My Subscription

[Test 2/7] 리소스 존재 확인
✓ PASS: Resource Group 존재: rg-aifoundry-20260203
✓ PASS: Storage Account 존재: staifoundry20260203
✓ PASS: AI Search Service 정상: srch-aifoundry-7kkykgt6

...

=============================================
  검증 결과 요약
=============================================

✓ PASS: 18
⚠ WARN: 2
✗ FAIL: 0

🎉 모든 테스트가 성공했습니다!
```

---

### 3. 기존 스크립트 (infra/scripts/)

이 스크립트들은 Terraform 배포를 위한 것입니다. 자세한 내용은 `infra/scripts/README.md`를 참조하세요.

---

## 🚀 빠른 시작 가이드

### 시나리오 1: 전체 배포 (처음 배포하는 경우)

```bash
# 1. Terraform 배포
cd infra
./scripts/deploy.sh

# 2. Jumpbox 접속 (Azure Bastion)
az network bastion rdp \
  --name bastion-jumpbox-krc \
  --resource-group rg-aifoundry-20260203 \
  --target-resource-id $(az vm show -g rg-aifoundry-20260203 -n vm-jb-win-krc --query id -o tsv)

# 3. Jumpbox에서 오프라인 배포 스크립트 실행
# (Windows Jumpbox)
cd C:\Users\azureuser\Downloads
.\jumpbox-offline-deploy.ps1

# (Linux Jumpbox)
cd ~/Downloads
./jumpbox-offline-deploy.sh

# 4. 배포 검증 (Jumpbox 또는 로컬에서)
./verify-deployment.sh
```

---

### 시나리오 2: 기존 배포 검증만

```bash
# Jumpbox 또는 개발 머신에서
cd scripts
./verify-deployment.sh
```

---

### 시나리오 3: 새 문서 업로드 및 인덱싱

```bash
# Jumpbox에서
cd ~/ai-foundry-examples

# 문서 업로드
./upload-document.sh /path/to/new-document.docx

# 또는 PowerShell
cd $HOME\ai-foundry-examples
.\upload-document.ps1 -FilePath C:\Documents\new-document.docx
```

---

### 시나리오 4: AI Search 검색 테스트

```bash
# Jumpbox에서
cd ~/ai-foundry-examples
./search-test.sh

# 또는 PowerShell
cd $HOME\ai-foundry-examples
.\search-test.ps1
```

---

### 시나리오 5: Python RAG 패턴 실행

```bash
# Jumpbox에서 (Python 3.8+ 필요)
cd ~/ai-foundry-examples

# 필요 패키지 설치
pip install azure-identity azure-search-documents openai

# 예제 실행
python3 playground-example.py
```

---

## 📋 사전 요구사항

### 모든 스크립트 공통

1. **Azure CLI**: 최신 버전 설치
   ```bash
   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Windows
   # https://learn.microsoft.com/cli/azure/install-azure-cli-windows
   ```

2. **Azure 로그인**: 스크립트 실행 전 로그인 필요
   ```bash
   az login
   az account set --subscription "<구독-ID>"
   ```

3. **필요한 권한**:
   - `Contributor` (리소스 생성/수정)
   - `User Access Administrator` (RBAC 설정)
   - `Storage Blob Data Contributor` (Storage 접근)
   - `Search Index Data Contributor` (AI Search 접근)

### Python 예제 추가 요구사항

```bash
# 패키지 설치
pip install azure-identity azure-search-documents openai

# 또는 requirements.txt 사용
pip install -r requirements.txt
```

---

## 🔧 환경 변수 커스터마이징

스크립트에서 사용하는 환경 변수를 변경하려면:

```bash
# Bash
export RESOURCE_GROUP="my-custom-rg"
export STORAGE_ACCOUNT="mycustomstorage"
export SEARCH_SERVICE="my-search-service"
./jumpbox-offline-deploy.sh

# PowerShell
$env:RESOURCE_GROUP = "my-custom-rg"
$env:STORAGE_ACCOUNT = "mycustomstorage"
.\jumpbox-offline-deploy.ps1
```

---

## 📊 로그 파일

모든 스크립트는 실행 중 로그를 `deploy.log` 파일에 기록합니다.

```bash
# 로그 확인
cat deploy.log

# 실시간 로그 모니터링
tail -f deploy.log
```

---

## ❓ 트러블슈팅

### 문제 1: "Azure CLI not found"

**해결**:
```bash
# Azure CLI 설치 확인
which az

# 없다면 설치
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

---

### 문제 2: "Permission denied"

**해결**:
```bash
# 스크립트 실행 권한 부여
chmod +x *.sh

# 또는 개별 스크립트
chmod +x jumpbox-offline-deploy.sh
```

---

### 문제 3: "Public access is not permitted"

**증상**: Storage 또는 Search 접근 시 오류

**원인**: Private DNS Zone이 VNet에 연결되지 않음

**해결**:
```bash
# DNS 해석 확인
nslookup staifoundry20260203.blob.core.windows.net
# 결과: 10.0.1.x (Private IP)여야 함

# Public IP로 해석되면 Private DNS Zone VNet Link 확인
az network private-dns link vnet list \
  --resource-group rg-aifoundry-20260203 \
  --zone-name privatelink.blob.core.windows.net
```

---

### 문제 4: "Indexer execution failed"

**증상**: AI Search Indexer 실행 실패

**원인**: RBAC 권한 부족

**해결**:
```bash
# Search Service Managed Identity에 Storage 읽기 권한 부여
SEARCH_PRINCIPAL_ID=$(az search service show \
  --name srch-aifoundry-xxx \
  --resource-group rg-aifoundry-20260203 \
  --query identity.principalId -o tsv)

az role assignment create \
  --assignee $SEARCH_PRINCIPAL_ID \
  --role "Storage Blob Data Reader" \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-aifoundry-20260203/providers/Microsoft.Storage/storageAccounts/staifoundry20260203
```

---

## 📚 관련 문서

- [배포 가이드](../docs/deployment-guide.md) - 전체 Terraform 배포 절차
- [Office 파일 RAG 가이드](../docs/office-file-rag-guide.md) - Office 파일 업로드 및 RAG 패턴
- [AI Search RAG 가이드](../docs/ai-search-rag-guide.md) - AI Search 구성
- [Jumpbox 접속 가이드](../docs/troubleshooting-ai-foundry-access.md) - 접속 및 문제 해결
- [보안 모범 사례](../docs/security-best-practices.md) - 보안 설정

---

## 🤝 기여

버그 리포트, 기능 제안, Pull Request를 환영합니다.

---

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.
