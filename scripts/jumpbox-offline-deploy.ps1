# =============================================================================
# Jumpbox 오프라인 배포 스크립트 (PowerShell)
# 
# 이 스크립트는 인터넷 연결이 제한된 Jumpbox 환경에서 
# AI Foundry 리소스를 구성하고 테스트하는 데 사용됩니다.
#
# 사용법:
#   .\jumpbox-offline-deploy.ps1
#
# 실행 환경:
#   - Windows Jumpbox (Windows 11)
#   - Azure CLI 및 PowerShell 7+ 설치 필요
#   - Private Network 접근 가능
# =============================================================================

# 스크립트 에러 시 중단
$ErrorActionPreference = "Stop"

# =============================================================================
# 함수 정의
# =============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
}

function Write-Section {
    param([string]$Step, [string]$Message)
    Write-Host "`n[Step $Step] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Blue
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    
    if ($Default) {
        $input = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrEmpty($input)) {
            return $Default
        }
        return $input
    }
    else {
        return Read-Host $Prompt
    }
}

function Test-CommandExists {
    param([string]$Command)
    
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# =============================================================================
# 메인 스크립트
# =============================================================================

Clear-Host
Write-Header "AI Foundry Private Networking - Jumpbox 배포 스크립트"

Write-Host "`n이 스크립트는 다음 작업을 수행합니다:" -ForegroundColor Magenta
Write-Host "  1. Azure 연결 확인"
Write-Host "  2. 리소스 그룹 및 주요 리소스 확인"
Write-Host "  3. Private Endpoint DNS 해석 테스트"
Write-Host "  4. Storage Account 구성"
Write-Host "  5. AI Search 인덱스 생성"
Write-Host "  6. 테스트 문서 업로드"
Write-Host "  7. AI Foundry 연결 테스트"
Write-Host "  8. Playground 예제 코드 생성"
Write-Host ""

# 계속 진행 확인
$confirm = Read-Host "계속 진행하시겠습니까? [y/N]"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "스크립트를 종료합니다."
    exit 0
}

# 로그 파일 초기화
$LogFile = Join-Path $PWD "deploy.log"
"=== Deployment Log $(Get-Date) ===" | Out-File -FilePath $LogFile

# =============================================================================
# Step 1: 환경 변수 설정
# =============================================================================

Write-Section "1/8" "환경 변수 설정"

# 기본값 설정
$DEFAULT_RESOURCE_GROUP = "rg-aifoundry-20260203"
$DEFAULT_LOCATION = "eastus"
$DEFAULT_STORAGE_ACCOUNT = "staifoundry20260203"
$DEFAULT_SEARCH_SERVICE = "srch-aifoundry-7kkykgt6"
$DEFAULT_AI_HUB = "aihub-foundry"
$DEFAULT_AI_PROJECT = "aiproj-agents"
$DEFAULT_CONTAINER_NAME = "documents"

# 사용자 입력 받기
$RESOURCE_GROUP = Get-UserInput -Prompt "Resource Group 이름" -Default $DEFAULT_RESOURCE_GROUP
$LOCATION = Get-UserInput -Prompt "Azure 리전" -Default $DEFAULT_LOCATION
$STORAGE_ACCOUNT = Get-UserInput -Prompt "Storage Account 이름" -Default $DEFAULT_STORAGE_ACCOUNT
$SEARCH_SERVICE = Get-UserInput -Prompt "AI Search Service 이름" -Default $DEFAULT_SEARCH_SERVICE
$AI_HUB = Get-UserInput -Prompt "AI Hub 이름" -Default $DEFAULT_AI_HUB
$AI_PROJECT = Get-UserInput -Prompt "AI Project 이름" -Default $DEFAULT_AI_PROJECT
$CONTAINER_NAME = Get-UserInput -Prompt "Blob Container 이름" -Default $DEFAULT_CONTAINER_NAME

Write-Success "환경 변수 설정 완료"
Write-Host ""
Write-Host "  Resource Group: $RESOURCE_GROUP"
Write-Host "  Location: $LOCATION"
Write-Host "  Storage Account: $STORAGE_ACCOUNT"
Write-Host "  Search Service: $SEARCH_SERVICE"
Write-Host "  AI Hub: $AI_HUB"
Write-Host "  AI Project: $AI_PROJECT"
Write-Host "  Container: $CONTAINER_NAME"

# =============================================================================
# Step 2: Azure 연결 확인
# =============================================================================

Write-Section "2/8" "Azure 연결 확인"

# Azure CLI 설치 확인
if (-not (Test-CommandExists "az")) {
    Write-Error-Custom "Azure CLI가 설치되어 있지 않습니다."
    Write-Info "Azure CLI 설치: https://learn.microsoft.com/cli/azure/install-azure-cli-windows"
    exit 1
}

Write-Success "Azure CLI 설치 확인"

# Azure 로그인 확인
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    $SUBSCRIPTION_ID = $account.id
    $SUBSCRIPTION_NAME = $account.name
    Write-Success "Azure 구독 확인: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}
catch {
    Write-Warning-Custom "Azure에 로그인되어 있지 않습니다. 로그인을 진행합니다..."
    az login
    $account = az account show | ConvertFrom-Json
    $SUBSCRIPTION_ID = $account.id
    $SUBSCRIPTION_NAME = $account.name
    Write-Success "Azure 구독 확인: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}

# =============================================================================
# Step 3: 리소스 존재 확인
# =============================================================================

Write-Section "3/8" "리소스 존재 확인"

# Resource Group 확인
try {
    az group show --name $RESOURCE_GROUP 2>&1 | Out-Null
    Write-Success "Resource Group 존재: $RESOURCE_GROUP"
}
catch {
    Write-Error-Custom "Resource Group이 존재하지 않습니다: $RESOURCE_GROUP"
    Write-Info "Terraform 배포를 먼저 실행하세요."
    exit 1
}

# Storage Account 확인
try {
    az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP 2>&1 | Out-Null
    Write-Success "Storage Account 존재: $STORAGE_ACCOUNT"
}
catch {
    Write-Error-Custom "Storage Account가 존재하지 않습니다: $STORAGE_ACCOUNT"
    exit 1
}

# AI Search 확인
try {
    az search service show --name $SEARCH_SERVICE --resource-group $RESOURCE_GROUP 2>&1 | Out-Null
    Write-Success "AI Search Service 존재: $SEARCH_SERVICE"
}
catch {
    Write-Error-Custom "AI Search Service가 존재하지 않습니다: $SEARCH_SERVICE"
    exit 1
}

# =============================================================================
# Step 4: Private Endpoint DNS 테스트
# =============================================================================

Write-Section "4/8" "Private Endpoint DNS 해석 테스트"

# Storage Blob DNS 테스트
$STORAGE_BLOB_FQDN = "$STORAGE_ACCOUNT.blob.core.windows.net"
Write-Host "→ Testing: $STORAGE_BLOB_FQDN" -ForegroundColor Cyan

try {
    $dnsResult = Resolve-DnsName -Name $STORAGE_BLOB_FQDN -Type A -ErrorAction Stop
    $ipAddress = $dnsResult[0].IPAddress
    
    if ($ipAddress -like "10.0.1.*") {
        Write-Success "Storage Blob Private Endpoint DNS 정상 (Private IP: $ipAddress)"
    }
    else {
        Write-Warning-Custom "Storage Blob이 Public IP로 해석됩니다: $ipAddress"
    }
}
catch {
    Write-Warning-Custom "DNS 해석 실패: $STORAGE_BLOB_FQDN"
}

# AI Search DNS 테스트
$SEARCH_FQDN = "$SEARCH_SERVICE.search.windows.net"
Write-Host "→ Testing: $SEARCH_FQDN" -ForegroundColor Cyan

try {
    $dnsResult = Resolve-DnsName -Name $SEARCH_FQDN -Type A -ErrorAction Stop
    $ipAddress = $dnsResult[0].IPAddress
    
    if ($ipAddress -like "10.0.1.*") {
        Write-Success "AI Search Private Endpoint DNS 정상 (Private IP: $ipAddress)"
    }
    else {
        Write-Warning-Custom "AI Search가 Public IP로 해석됩니다: $ipAddress"
    }
}
catch {
    Write-Warning-Custom "DNS 해석 실패: $SEARCH_FQDN"
}

# =============================================================================
# Step 5: Storage Container 생성
# =============================================================================

Write-Section "5/8" "Storage Container 생성"

# Container 존재 확인
$containerExists = az storage container exists `
    --name $CONTAINER_NAME `
    --account-name $STORAGE_ACCOUNT `
    --auth-mode login `
    --query exists -o tsv 2>&1

if ($containerExists -eq "true") {
    Write-Info "Container가 이미 존재합니다: $CONTAINER_NAME"
}
else {
    Write-Host "→ Container 생성 중..." -ForegroundColor Cyan
    try {
        az storage container create `
            --name $CONTAINER_NAME `
            --account-name $STORAGE_ACCOUNT `
            --auth-mode login 2>&1 | Out-File -Append -FilePath $LogFile
        Write-Success "Container 생성 완료: $CONTAINER_NAME"
    }
    catch {
        Write-Error-Custom "Container 생성 실패"
        exit 1
    }
}

# =============================================================================
# Step 6: 테스트 문서 생성 및 업로드
# =============================================================================

Write-Section "6/8" "테스트 문서 생성 및 업로드"

# 임시 디렉토리 생성
$TEMP_DIR = Join-Path $env:TEMP "test_documents"
if (-not (Test-Path $TEMP_DIR)) {
    New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null
}

Write-Info "임시 디렉토리: $TEMP_DIR"

# 테스트 문서 생성
$doc1 = @"
Azure AI Foundry 플랫폼 소개

Azure AI Foundry는 Microsoft의 통합 AI 개발 플랫폼으로, 
다음과 같은 주요 기능을 제공합니다:

1. 프라이빗 네트워킹 지원
   - Private Endpoints를 통한 안전한 접근
   - VNet 통합으로 네트워크 격리
   - Azure Bastion을 통한 보안 접속

2. AI 모델 통합
   - Azure OpenAI GPT-4o
   - Text Embedding Ada-002
   - 커스텀 모델 배포

3. RAG 패턴 지원
   - Azure AI Search 통합
   - 문서 인덱싱 및 검색
   - Semantic Search

4. 멀티 리전 구성
   - East US: AI Foundry Hub/Project
   - Korea Central: Jumpbox 및 Bastion

이 플랫폼을 사용하면 엔터프라이즈급 AI 솔루션을 
안전하고 효율적으로 구축할 수 있습니다.
"@

$doc2 = @"
RAG 패턴 구현 가이드

RAG (Retrieval-Augmented Generation)는 
검색 기반 AI 응답 생성 패턴입니다.

구성 요소:
1. 문서 저장소: Azure Blob Storage
2. 검색 엔진: Azure AI Search
3. 임베딩 모델: text-embedding-ada-002
4. 생성 모델: GPT-4o

구현 단계:
1. 문서를 Blob Storage에 업로드
2. AI Search 인덱서로 문서 인덱싱
3. 사용자 질문을 임베딩으로 변환
4. 유사 문서 검색
5. 검색 결과를 컨텍스트로 GPT-4o 호출
6. 최종 응답 생성

이 패턴을 사용하면 최신 정보를 기반으로
정확한 AI 응답을 생성할 수 있습니다.
"@

$doc3 = @"
프라이빗 네트워킹 보안 가이드

Zero Trust 보안 원칙:
1. 모든 서비스는 Private Endpoint로만 접근
2. Public Network Access 비활성화
3. NSG로 트래픽 제어
4. Managed Identity로 인증

네트워크 보안 설정:
- VNet Peering: Korea Central ↔ East US
- Private DNS Zones: 10개 DNS Zone 구성
- NSG Rules: 최소 권한 원칙
- Azure Bastion: Jumpbox 보안 접속

RBAC 권한 설정:
- Storage Blob Data Contributor
- Cognitive Services User
- Key Vault Secrets Officer
- Search Index Data Contributor

이러한 보안 설정을 통해 엔터프라이즈급
보안 수준을 유지할 수 있습니다.
"@

# 문서 저장
$doc1 | Out-File -FilePath (Join-Path $TEMP_DIR "AI_Foundry_소개.txt") -Encoding UTF8
$doc2 | Out-File -FilePath (Join-Path $TEMP_DIR "RAG_패턴_가이드.txt") -Encoding UTF8
$doc3 | Out-File -FilePath (Join-Path $TEMP_DIR "보안_가이드.txt") -Encoding UTF8

Write-Success "테스트 문서 생성 완료 (3개)"

# 문서 업로드
Write-Info "문서 업로드 중..."
Get-ChildItem -Path $TEMP_DIR -Filter "*.txt" | ForEach-Object {
    $filename = $_.Name
    Write-Host "→ 업로드: $filename" -ForegroundColor Cyan
    
    try {
        az storage blob upload `
            --account-name $STORAGE_ACCOUNT `
            --container-name $CONTAINER_NAME `
            --name $filename `
            --file $_.FullName `
            --auth-mode login `
            --overwrite 2>&1 | Out-File -Append -FilePath $LogFile
        Write-Success "$filename 업로드 완료"
    }
    catch {
        Write-Warning-Custom "$filename 업로드 실패 (이미 존재하거나 권한 부족)"
    }
}

# 업로드된 파일 확인
Write-Info "업로드된 파일 목록:"
az storage blob list `
    --account-name $STORAGE_ACCOUNT `
    --container-name $CONTAINER_NAME `
    --auth-mode login `
    --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" `
    --output table

# =============================================================================
# Step 7: AI Search 인덱스 생성
# =============================================================================

Write-Section "7/8" "AI Search 인덱스 생성"

$INDEX_NAME = "aifoundry-docs-index"
$SEARCH_ENDPOINT = "https://$SEARCH_SERVICE.search.windows.net"

Write-Info "Search Endpoint: $SEARCH_ENDPOINT"
Write-Info "Index Name: $INDEX_NAME"

# 인덱스 스키마 정의
$INDEX_SCHEMA = @"
{
    "name": "$INDEX_NAME",
    "fields": [
        {
            "name": "id",
            "type": "Edm.String",
            "key": true,
            "filterable": true
        },
        {
            "name": "content",
            "type": "Edm.String",
            "searchable": true,
            "analyzer": "ko.microsoft"
        },
        {
            "name": "title",
            "type": "Edm.String",
            "searchable": true,
            "filterable": true,
            "sortable": true
        },
        {
            "name": "metadata_storage_name",
            "type": "Edm.String",
            "searchable": true,
            "filterable": true
        },
        {
            "name": "metadata_storage_path",
            "type": "Edm.String",
            "filterable": true
        }
    ]
}
"@

# 인덱스 생성
Write-Info "인덱스 생성 중..."
try {
    $INDEX_SCHEMA | Out-File -FilePath "$TEMP_DIR\index-schema.json" -Encoding UTF8
    
    az rest `
        --method PUT `
        --url "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" `
        --headers "Content-Type=application/json" `
        --body "@$TEMP_DIR\index-schema.json" `
        --resource "https://search.azure.com" 2>&1 | Out-File -Append -FilePath $LogFile
    
    Write-Success "인덱스 생성 완료: $INDEX_NAME"
}
catch {
    Write-Warning-Custom "인덱스 생성 실패 (이미 존재하거나 권한 부족)"
}

# Data Source 생성
$DATASOURCE_NAME = "aifoundry-blob-datasource"
$STORAGE_RESOURCE_ID = az storage account show `
    --name $STORAGE_ACCOUNT `
    --resource-group $RESOURCE_GROUP `
    --query id -o tsv

$DATASOURCE_SCHEMA = @"
{
    "name": "$DATASOURCE_NAME",
    "type": "azureblob",
    "credentials": {
        "connectionString": "ResourceId=$STORAGE_RESOURCE_ID;"
    },
    "container": {
        "name": "$CONTAINER_NAME"
    },
    "dataChangeDetectionPolicy": {
        "@odata.type": "#Microsoft.Azure.Search.HighWaterMarkChangeDetectionPolicy",
        "highWaterMarkColumnName": "_ts"
    }
}
"@

Write-Info "Data Source 생성 중..."
try {
    $DATASOURCE_SCHEMA | Out-File -FilePath "$TEMP_DIR\datasource-schema.json" -Encoding UTF8
    
    az rest `
        --method PUT `
        --url "$SEARCH_ENDPOINT/datasources/$DATASOURCE_NAME?api-version=2024-07-01" `
        --headers "Content-Type=application/json" `
        --body "@$TEMP_DIR\datasource-schema.json" `
        --resource "https://search.azure.com" 2>&1 | Out-File -Append -FilePath $LogFile
    
    Write-Success "Data Source 생성 완료: $DATASOURCE_NAME"
}
catch {
    Write-Warning-Custom "Data Source 생성 실패 (이미 존재하거나 권한 부족)"
}

# Indexer 생성
$INDEXER_NAME = "aifoundry-docs-indexer"
$INDEXER_SCHEMA = @"
{
    "name": "$INDEXER_NAME",
    "dataSourceName": "$DATASOURCE_NAME",
    "targetIndexName": "$INDEX_NAME",
    "schedule": {
        "interval": "PT2H"
    },
    "parameters": {
        "configuration": {
            "parsingMode": "text"
        }
    },
    "fieldMappings": [
        {
            "sourceFieldName": "metadata_storage_name",
            "targetFieldName": "title"
        }
    ]
}
"@

Write-Info "Indexer 생성 중..."
try {
    $INDEXER_SCHEMA | Out-File -FilePath "$TEMP_DIR\indexer-schema.json" -Encoding UTF8
    
    az rest `
        --method PUT `
        --url "$SEARCH_ENDPOINT/indexers/$INDEXER_NAME?api-version=2024-07-01" `
        --headers "Content-Type=application/json" `
        --body "@$TEMP_DIR\indexer-schema.json" `
        --resource "https://search.azure.com" 2>&1 | Out-File -Append -FilePath $LogFile
    
    Write-Success "Indexer 생성 완료: $INDEXER_NAME"
}
catch {
    Write-Warning-Custom "Indexer 생성 실패 (이미 존재하거나 권한 부족)"
}

# Indexer 실행
Write-Info "Indexer 실행 중..."
try {
    az rest `
        --method POST `
        --url "$SEARCH_ENDPOINT/indexers/$INDEXER_NAME/run?api-version=2024-07-01" `
        --resource "https://search.azure.com" 2>&1 | Out-File -Append -FilePath $LogFile
    
    Write-Success "Indexer 실행 완료"
    Write-Info "인덱싱 완료까지 1-2분 소요됩니다."
}
catch {
    Write-Warning-Custom "Indexer 실행 실패"
}

# =============================================================================
# Step 8: AI Foundry 연결 테스트
# =============================================================================

Write-Section "8/8" "AI Foundry 연결 테스트"

# AI Hub 확인
Write-Info "AI Hub 확인 중..."
try {
    $hubName = az ml workspace show `
        --name $AI_HUB `
        --resource-group $RESOURCE_GROUP `
        --query name -o tsv 2>&1
    
    Write-Success "AI Hub 존재: $hubName"
}
catch {
    Write-Error-Custom "AI Hub가 존재하지 않습니다: $AI_HUB"
    exit 1
}

# Azure OpenAI 엔드포인트 확인
$OPENAI_ACCOUNT = az cognitiveservices account list `
    --resource-group $RESOURCE_GROUP `
    --query "[?kind=='OpenAI'].name" -o tsv 2>&1 | Select-Object -First 1

if ($OPENAI_ACCOUNT) {
    $OPENAI_ENDPOINT = az cognitiveservices account show `
        --name $OPENAI_ACCOUNT `
        --resource-group $RESOURCE_GROUP `
        --query properties.endpoint -o tsv
    Write-Success "Azure OpenAI 엔드포인트: $OPENAI_ENDPOINT"
}
else {
    Write-Warning-Custom "Azure OpenAI 계정을 찾을 수 없습니다."
}

# =============================================================================
# 예제 코드 생성
# =============================================================================

Write-Header "예제 코드 생성"

# 예제 디렉토리 생성
$EXAMPLE_DIR = Join-Path $HOME "ai-foundry-examples"
if (-not (Test-Path $EXAMPLE_DIR)) {
    New-Item -ItemType Directory -Path $EXAMPLE_DIR | Out-Null
}

Write-Info "예제 코드 저장 위치: $EXAMPLE_DIR"

# 1. AI Search 검색 예제 (PowerShell)
$searchTestScript = @"
# AI Search 검색 테스트

`$SEARCH_ENDPOINT = "https://$SEARCH_SERVICE.search.windows.net"
`$INDEX_NAME = "$INDEX_NAME"

Write-Host "AI Search 검색 테스트..." -ForegroundColor Green

# Azure AD 토큰 가져오기
`$TOKEN = az account get-access-token --resource https://search.azure.com --query accessToken -o tsv

# 검색 요청 본문
`$searchBody = @{
    search = "AI Foundry"
    top = 3
    select = "title, content"
} | ConvertTo-Json

# 검색 실행
`$headers = @{
    "Authorization" = "Bearer `$TOKEN"
    "Content-Type" = "application/json"
}

`$response = Invoke-RestMethod `
    -Uri "`$SEARCH_ENDPOINT/indexes/`$INDEX_NAME/docs/search?api-version=2024-07-01" `
    -Method POST `
    -Headers `$headers `
    -Body `$searchBody

# 결과 출력
`$response | ConvertTo-Json -Depth 5

Write-Host "`n검색 완료!" -ForegroundColor Green
"@

$searchTestScript | Out-File -FilePath (Join-Path $EXAMPLE_DIR "search-test.ps1") -Encoding UTF8
Write-Success "AI Search 검색 예제: $EXAMPLE_DIR\search-test.ps1"

# 2. Blob 파일 업로드 예제
$uploadScript = @"
# Blob Storage 파일 업로드 예제

param(
    [Parameter(Mandatory=`$true)]
    [string]`$FilePath
)

`$STORAGE_ACCOUNT = "$STORAGE_ACCOUNT"
`$CONTAINER_NAME = "$CONTAINER_NAME"

# 파일 존재 확인
if (-not (Test-Path `$FilePath)) {
    Write-Host "파일을 찾을 수 없습니다: `$FilePath" -ForegroundColor Red
    exit 1
}

`$FileName = Split-Path `$FilePath -Leaf

Write-Host "파일 업로드 중: `$FileName" -ForegroundColor Green

# 파일 업로드
az storage blob upload ``
    --account-name `$STORAGE_ACCOUNT ``
    --container-name `$CONTAINER_NAME ``
    --name `$FileName ``
    --file `$FilePath ``
    --auth-mode login ``
    --overwrite

Write-Host "업로드 완료: `$FileName" -ForegroundColor Green

# Indexer 수동 실행
Write-Host "Indexer 실행 중..." -ForegroundColor Yellow

`$SEARCH_ENDPOINT = "https://$SEARCH_SERVICE.search.windows.net"
`$INDEXER_NAME = "$INDEXER_NAME"
`$TOKEN = az account get-access-token --resource https://search.azure.com --query accessToken -o tsv

`$headers = @{
    "Authorization" = "Bearer `$TOKEN"
}

Invoke-RestMethod ``
    -Uri "`$SEARCH_ENDPOINT/indexers/`$INDEXER_NAME/run?api-version=2024-07-01" ``
    -Method POST ``
    -Headers `$headers

Write-Host "`n완료! 1-2분 후 AI Foundry Playground에서 문서를 검색할 수 있습니다." -ForegroundColor Green
"@

$uploadScript | Out-File -FilePath (Join-Path $EXAMPLE_DIR "upload-document.ps1") -Encoding UTF8
Write-Success "파일 업로드 예제: $EXAMPLE_DIR\upload-document.ps1"

# 3. Python 예제 (AI Foundry Playground 스타일)
$pythonExample = @"
#!/usr/bin/env python3
`"""
AI Foundry Playground 스타일 예제 코드

이 코드는 AI Foundry Playground에서 생성된 코드와 동일한 형태로
Azure OpenAI + AI Search RAG 패턴을 구현합니다.
`"""

import os
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from openai import AzureOpenAI

# 환경 변수 설정
SEARCH_ENDPOINT = "https://$SEARCH_SERVICE.search.windows.net"
SEARCH_INDEX = "$INDEX_NAME"
OPENAI_ENDPOINT = "https://$OPENAI_ACCOUNT.openai.azure.com"
OPENAI_DEPLOYMENT = "gpt-4o"

def search_documents(query: str, top_k: int = 3):
    `"""AI Search에서 문서 검색`"""
    credential = DefaultAzureCredential()
    search_client = SearchClient(
        endpoint=SEARCH_ENDPOINT,
        index_name=SEARCH_INDEX,
        credential=credential
    )
    
    results = search_client.search(
        search_text=query,
        top=top_k,
        select=["title", "content"]
    )
    
    documents = []
    for result in results:
        documents.append({
            "title": result.get("title", ""),
            "content": result.get("content", "")
        })
    
    return documents

def generate_response(query: str, documents: list):
    `"""검색된 문서를 기반으로 GPT-4o 응답 생성`"""
    credential = DefaultAzureCredential()
    client = AzureOpenAI(
        azure_endpoint=OPENAI_ENDPOINT,
        api_version="2024-10-21",
        azure_ad_token_provider=credential.get_token("https://cognitiveservices.azure.com/.default")
    )
    
    # 문서를 컨텍스트로 결합
    context = "\n\n".join([
        f"[{doc['title']}]\n{doc['content']}"
        for doc in documents
    ])
    
    # System prompt (RAG 패턴)
    system_prompt = f`"""당신은 제공된 문서를 기반으로 정확한 답변을 제공하는 AI 어시스턴트입니다.
다음 문서를 참고하여 사용자의 질문에 답변하세요:

{context}

문서에 정보가 없으면 "제공된 문서에서 해당 정보를 찾을 수 없습니다"라고 답변하세요.`"""
    
    # GPT-4o 호출
    response = client.chat.completions.create(
        model=OPENAI_DEPLOYMENT,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": query}
        ],
        temperature=0.7,
        max_tokens=800
    )
    
    return response.choices[0].message.content

def main():
    `"""메인 함수`"""
    print("=" * 60)
    print("AI Foundry RAG 패턴 예제")
    print("=" * 60)
    
    # 사용자 질문
    query = input("\n질문을 입력하세요: ")
    
    # 1. 문서 검색
    print(f"\n[1/2] AI Search에서 문서 검색 중: '{query}'")
    documents = search_documents(query)
    print(f"검색 결과: {len(documents)}개 문서")
    
    for i, doc in enumerate(documents, 1):
        print(f"  {i}. {doc['title']}")
    
    # 2. GPT-4o 응답 생성
    print("\n[2/2] GPT-4o로 응답 생성 중...")
    answer = generate_response(query, documents)
    
    # 결과 출력
    print("\n" + "=" * 60)
    print("답변:")
    print("=" * 60)
    print(answer)
    print("\n" + "=" * 60)

if __name__ == "__main__":
    main()
"@

$pythonExample | Out-File -FilePath (Join-Path $EXAMPLE_DIR "playground-example.py") -Encoding UTF8
Write-Success "Python 예제: $EXAMPLE_DIR\playground-example.py"

# =============================================================================
# 배포 완료 요약
# =============================================================================

Write-Header "배포 완료!"

Write-Host "`n✓ 모든 작업이 완료되었습니다!`n" -ForegroundColor Green

Write-Host "배포된 리소스:" -ForegroundColor Magenta
Write-Host "  - Resource Group: $RESOURCE_GROUP"
Write-Host "  - Storage Account: $STORAGE_ACCOUNT"
Write-Host "  - Container: $CONTAINER_NAME"
Write-Host "  - AI Search: $SEARCH_SERVICE"
Write-Host "  - Index: $INDEX_NAME"
Write-Host "  - Indexer: $INDEXER_NAME"
Write-Host "  - AI Hub: $AI_HUB"
Write-Host "  - AI Project: $AI_PROJECT"

Write-Host "`n생성된 파일:" -ForegroundColor Magenta
Write-Host "  - 테스트 문서: 3개 (Blob Storage에 업로드됨)"
Write-Host "  - 예제 스크립트: $EXAMPLE_DIR\"
Write-Host "    • search-test.ps1 - AI Search 검색 테스트"
Write-Host "    • upload-document.ps1 - 문서 업로드"
Write-Host "    • playground-example.py - Python RAG 예제"

Write-Host "`n다음 단계:" -ForegroundColor Magenta
Write-Host "  1. AI Foundry Portal 접속: https://ai.azure.com"
Write-Host "  2. Hub 선택: $AI_HUB"
Write-Host "  3. Project 선택: $AI_PROJECT"
Write-Host "  4. Playground → Chat 탭"
Write-Host "  5. 'Add your data' → Azure AI Search 선택"
Write-Host "  6. Index: $INDEX_NAME 선택"
Write-Host "  7. 테스트 질문 입력:"
Write-Host "     • Azure AI Foundry의 주요 기능은?"
Write-Host "     • RAG 패턴의 구성 요소는?"
Write-Host "     • 프라이빗 네트워킹 보안 설정은?"

Write-Host "`n예제 실행 방법:" -ForegroundColor Magenta
Write-Host "  # AI Search 검색 테스트"
Write-Host "  PS> cd $EXAMPLE_DIR"
Write-Host "  PS> .\search-test.ps1"
Write-Host ""
Write-Host "  # 새 문서 업로드"
Write-Host "  PS> .\upload-document.ps1 -FilePath C:\path\to\document.txt"
Write-Host ""
Write-Host "  # Python RAG 예제"
Write-Host "  PS> python playground-example.py"

Write-Host "`n로그 파일: $LogFile" -ForegroundColor Cyan
Write-Host "배포 스크립트 실행이 완료되었습니다.`n" -ForegroundColor Green
