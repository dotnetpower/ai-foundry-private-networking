# AI Foundry 스크립트 가이드

이 디렉토리는 AI Foundry 인프라 구성 및 검증을 위한 스크립트를 포함합니다.

## 스크립트 목록

### 1. Jumpbox 오프라인 배포 스크립트

#### `jumpbox-offline-deploy.sh` (Bash - Linux Jumpbox용)

**용도**: 프라이빗 네트워크 내 Linux Jumpbox에서 AI Foundry 리소스를 구성하고 테스트

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
2. 리소스 존재 확인 (Resource Group, Storage, Search, Foundry Account)
3. Private Endpoint DNS 해석 테스트
4. Storage Container 생성
5. 테스트 문서 생성 및 업로드
6. AI Search 인덱스/Data Source/Indexer 생성
7. AI Foundry 연결 테스트
8. 예제 코드 생성 (Bash, Python)

**생성되는 파일**:
- `~/ai-foundry-examples/search-test.sh` - AI Search 검색 테스트
- `~/ai-foundry-examples/upload-document.sh` - 문서 업로드 스크립트
- `~/ai-foundry-examples/playground-example.py` - Python RAG 예제

---

#### `jumpbox-offline-deploy.ps1` (PowerShell - Windows Jumpbox용)

**용도**: 프라이빗 네트워크 내 Windows Jumpbox에서 AI Foundry 리소스를 구성하고 테스트

**실행 환경**:
- Windows 11 Pro
- PowerShell 7+
- Azure CLI 설치 필요

**사용법**:
```powershell
.\jumpbox-offline-deploy.ps1
```

**생성되는 파일**:
- `$HOME\ai-foundry-examples\search-test.ps1` - AI Search 검색 테스트
- `$HOME\ai-foundry-examples\upload-document.ps1` - 문서 업로드 스크립트
- `$HOME\ai-foundry-examples\playground-example.py` - Python RAG 예제

---

### 2. 배포 검증 스크립트

#### `verify-deployment.sh` (Bash)

**용도**: 배포된 AI Foundry 인프라를 자동으로 검증

**사용법**:
```bash
chmod +x verify-deployment.sh
./verify-deployment.sh
```

**검증 항목** (7개 테스트):
1. Azure 연결 및 CLI 확인
2. 리소스 존재 확인 (Resource Group, Storage, Search, Foundry Account)
3. Private Endpoint DNS 해석 테스트
4. Storage Account 접근 테스트
5. AI Search 검색 테스트
6. 모델 배포 확인
7. End-to-End RAG 패턴 테스트

---

### 3. 테스트 문서 생성

#### `generate_test_documents.py` (Python)

**용도**: RAG 테스트용 샘플 문서 생성

**사용법**:
```bash
python generate_test_documents.py
```

**생성되는 문서**:
- `test_documents/` 디렉토리에 샘플 텍스트 파일 생성

---

### 4. AI Search RAG 설정

#### `setup-ai-search-rag.sh` (Bash)

**용도**: AI Search 인덱스 및 Data Source 설정

**사용법**:
```bash
chmod +x setup-ai-search-rag.sh
./setup-ai-search-rag.sh
```

---

## 빠른 시작 가이드

### 시나리오 1: Bicep 배포 후 Jumpbox 구성

```bash
# 1. Bicep 배포 (infra-bicep/ 디렉토리에서)
cd infra-bicep
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam

# 2. Jumpbox 접속 (Azure Bastion)
az network bastion ssh \
  --name bastion-aifoundry \
  --resource-group <rg-name> \
  --target-resource-id $(az vm show -g <rg-name> -n vm-jumpbox-linux --query id -o tsv) \
  --auth-type password \
  --username azureuser

# 3. Jumpbox에서 오프라인 배포 스크립트 실행
./jumpbox-offline-deploy.sh

# 4. 배포 검증
./verify-deployment.sh
```

### 시나리오 2: 기존 배포 검증

```bash
cd scripts
./verify-deployment.sh
```

### 시나리오 3: AI Search 검색 테스트

```bash
# Jumpbox에서
cd ~/ai-foundry-examples
./search-test.sh
```

---

## 환경 변수

스크립트에서 사용되는 환경 변수:

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `RESOURCE_GROUP` | 리소스 그룹 이름 | 대화형 입력 |
| `STORAGE_ACCOUNT` | Storage Account 이름 | 대화형 입력 |
| `SEARCH_SERVICE` | AI Search 서비스 이름 | 대화형 입력 |
| `FOUNDRY_ACCOUNT` | AI Foundry Account 이름 | 대화형 입력 |

---

## 참고 사항

- 모든 스크립트는 Azure CLI 인증이 필요합니다 (`az login`)
- Jumpbox 스크립트는 프라이빗 네트워크 내에서 실행해야 합니다
- Python 스크립트는 Python 3.8+ 필요
