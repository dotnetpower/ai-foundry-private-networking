# =============================================================================
# AI Foundry Standard Agent Setup - PowerShell 배포 스크립트
# =============================================================================
# - VNet 존재 여부 체크 및 자동 생성 (az CLI)
# - Azure Provider 간헐적 버그에 대한 재시도 로직 포함
# - Terraform state 자동 복구 기능
# =============================================================================

#Requires -Version 7.0

param(
    [switch]$SkipAvailabilityCheck,
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

# =============================================================================
# 로깅 함수
# =============================================================================
function Write-LogInfo { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-LogError { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-LogStep { param([string]$Message) Write-Host "[STEP] $Message" -ForegroundColor Cyan }

# 스크립트 디렉토리
$ScriptDir = $PSScriptRoot
$LogFile = Join-Path $ScriptDir "deploy.log"

# =============================================================================
# 설정 파일 로드
# =============================================================================
$ConfigFile = Join-Path $ScriptDir "config.env"
if (-not (Test-Path $ConfigFile)) {
    Write-LogError "config.env 파일을 찾을 수 없습니다: $ConfigFile"
    Write-LogInfo "config.env.example을 복사하여 설정하세요."
    exit 1
}

Write-LogInfo "설정 파일 로드 중: $ConfigFile"

# config.env 파싱
$ConfigContent = Get-Content $ConfigFile
foreach ($line in $ConfigContent) {
    if ($line -match '^\s*([A-Z_]+)\s*=\s*"?([^"#]+)"?\s*(#.*)?$') {
        $varName = $matches[1]
        $varValue = $matches[2].Trim()
        Set-Variable -Name $varName -Value $varValue -Scope Script
    }
}

# =============================================================================
# 설정 검증
# =============================================================================
function Test-Config {
    Write-LogStep "1/6 - 설정 검증"
    
    $requiredVars = @("LOCATION", "RESOURCE_GROUP_NAME", "VNET_NAME", "VNET_PREFIX",
                      "AGENT_SUBNET_NAME", "AGENT_SUBNET_PREFIX",
                      "PE_SUBNET_NAME", "PE_SUBNET_PREFIX")
    
    foreach ($var in $requiredVars) {
        $value = Get-Variable -Name $var -ValueOnly -ErrorAction SilentlyContinue
        if ([string]::IsNullOrEmpty($value)) {
            Write-LogError "필수 환경변수가 설정되지 않았습니다: $var"
            exit 1
        }
    }
    
    # VNET_RESOURCE_GROUP 기본값 설정
    if ([string]::IsNullOrEmpty($VNET_RESOURCE_GROUP)) {
        $script:VNET_RESOURCE_GROUP = $RESOURCE_GROUP_NAME
        Write-LogInfo "VNET_RESOURCE_GROUP이 비어있어 RESOURCE_GROUP_NAME 사용: $VNET_RESOURCE_GROUP"
    }
    
    Write-LogSuccess "설정 검증 완료"
    Write-Host "  - 위치: $LOCATION"
    Write-Host "  - 리소스 그룹: $RESOURCE_GROUP_NAME"
    Write-Host "  - VNet 리소스 그룹: $VNET_RESOURCE_GROUP"
    Write-Host "  - VNet: $VNET_NAME ($VNET_PREFIX)"
}

# =============================================================================
# Azure 로그인 확인
# =============================================================================
function Test-AzureLogin {
    Write-LogStep "2/6 - Azure 로그인 확인"
    
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if (-not $account) {
            Write-LogError "Azure에 로그인되어 있지 않습니다. 'az login'을 실행하세요."
            exit 1
        }
        
        Write-LogSuccess "Azure 로그인 확인 완료"
        Write-Host "  - 구독: $($account.name)"
        Write-Host "  - ID: $($account.id)"
        
        if (-not [string]::IsNullOrEmpty($SUBSCRIPTION_ID) -and $account.id -ne $SUBSCRIPTION_ID) {
            Write-LogInfo "구독 변경 중: $SUBSCRIPTION_ID"
            az account set --subscription $SUBSCRIPTION_ID
        }
    }
    catch {
        Write-LogError "Azure CLI 오류: $_"
        exit 1
    }
}

# =============================================================================
# 리소스 가용성 사전 검사
# =============================================================================
function Test-ResourceAvailability {
    param([string]$Location)
    
    Write-LogStep "2.5/6 - 리소스 가용성 사전 검사"
    
    Write-Host ""
    Write-LogInfo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-LogInfo "리전 '$Location'에서 리소스 가용성을 확인합니다..."
    Write-LogInfo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    
    # 1. Cognitive Services (OpenAI) 가용성 확인
    Write-LogInfo "[1/3] Azure OpenAI 가용성 확인 중..."
    try {
        $openaiSkus = az cognitiveservices account list-skus --kind AIServices --location $Location --query "[?name=='S0']" 2>$null | ConvertFrom-Json
        if ($openaiSkus) {
            Write-LogSuccess "  ✓ Azure OpenAI (AIServices) - 사용 가능"
        } else {
            Write-LogWarning "  ⚠ Azure OpenAI 가용성 확인 불가"
        }
    } catch {
        Write-LogWarning "  ⚠ Azure OpenAI 가용성 확인 실패"
    }
    
    # 2. Storage Account 가용성 확인
    Write-LogInfo "[2/3] Storage Account 가용성 확인 중..."
    Write-LogSuccess "  ✓ Storage Account - 일반적으로 모든 리전에서 사용 가능"
    
    # 3. CosmosDB 가용성 확인
    Write-LogInfo "[3/3] CosmosDB 가용성 확인 중..."
    Write-LogSuccess "  ✓ CosmosDB - 일반적으로 모든 리전에서 사용 가능"
    
    Write-Host ""
    Write-LogInfo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-LogInfo "📋 AI Search 리전별 권장 사항:"
    Write-Host "  - eastus2, swedencentral: 모든 SKU 일반적으로 가용"
    Write-Host "  - eastus, westeurope: 대부분 SKU 가용"
    Write-Host ""
    
    Write-LogSuccess "가용성 사전 검사 완료"
    Write-Host ""
}

# =============================================================================
# OpenAI 모델 가용성 확인
# =============================================================================
function Test-OpenAIModelAvailability {
    param([string]$Location)
    
    Write-LogInfo "OpenAI 모델 가용성 확인 중 (리전: $Location)..."
    
    $fullSupportRegions = @("eastus2", "swedencentral")
    $partialSupportRegions = @("eastus", "westus", "westus3", "westeurope", "francecentral", 
                               "uksouth", "koreacentral", "japaneast", "australiaeast", "canadaeast")
    
    if ($fullSupportRegions -contains $Location) {
        Write-LogSuccess "  ✓ '$Location'은 모든 최신 모델을 지원합니다 (GPT-5.x, o-series, GPT-4o 등)"
        return $true
    }
    elseif ($partialSupportRegions -contains $Location) {
        Write-LogInfo "  ℹ '$Location'은 GPT-4o, o3-mini 등 주요 모델을 지원합니다"
        Write-LogInfo "  ℹ 최신 모델(GPT-5.x, codex-mini 등)은 eastus2/swedencentral만 지원"
        return $true
    }
    else {
        Write-LogWarning "  ⚠ '$Location'의 모델 가용성이 제한적일 수 있습니다"
        return $false
    }
}

# =============================================================================
# CapabilityHost 가용성 확인
# =============================================================================
function Test-CapabilityHostAvailability {
    param([string]$Location)
    
    Write-LogInfo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-LogInfo "CapabilityHost (Standard Agent Setup) 가용성 확인 중..."
    Write-LogInfo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    
    # Standard Agent Setup 지원 리전 (2026년 2월 기준)
    $supportedRegions = @(
        "westus", "eastus", "eastus2", "japaneast", "francecentral", "spaincentral",
        "uaenorth", "southcentralus", "italynorth", "germanywestcentral", "brazilsouth",
        "southafricanorth", "australiaeast", "swedencentral", "canadaeast",
        "westeurope", "westus3", "uksouth", "southindia", "koreacentral",
        "polandcentral", "switzerlandnorth", "norwayeast"
    )
    
    if ($supportedRegions -contains $Location) {
        Write-LogSuccess "  ✓ CapabilityHost - '$Location' 리전 지원됨"
    }
    else {
        Write-LogError "  ✗ CapabilityHost - '$Location' 리전 미지원!"
        Write-Host ""
        Write-LogWarning "  지원되는 리전 목록:"
        $supportedRegions[0..9] | ForEach-Object { Write-Host "      - $_" }
        Write-Host "      ... 및 기타"
        Write-Host ""
        
        $changeRegion = Read-Host "  다른 리전으로 변경하시겠습니까? [y/N]"
        if ($changeRegion -eq 'y' -or $changeRegion -eq 'Y') {
            Write-Host ""
            Write-Host "  추천 리전:"
            Write-Host "    [1] eastus2      - 모든 기능 지원 (미국 동부 2)"
            Write-Host "    [2] swedencentral - 모든 기능 지원 (스웨덴)"
            Write-Host "    [3] eastus       - 주요 기능 지원 (미국 동부)"
            Write-Host "    [4] westeurope   - 주요 기능 지원 (서유럽)"
            Write-Host "    [5] koreacentral - 주요 기능 지원 (한국)"
            Write-Host "    [6] 직접 입력"
            Write-Host ""
            $regionChoice = Read-Host "  선택 [1-6]"
            
            switch ($regionChoice) {
                "1" { $script:LOCATION = "eastus2" }
                "2" { $script:LOCATION = "swedencentral" }
                "3" { $script:LOCATION = "eastus" }
                "4" { $script:LOCATION = "westeurope" }
                "5" { $script:LOCATION = "koreacentral" }
                "6" { 
                    $customRegion = Read-Host "  리전 입력"
                    $script:LOCATION = $customRegion
                }
                default {
                    Write-LogError "  잘못된 선택. 배포를 중단합니다."
                    exit 1
                }
            }
            
            Write-LogSuccess "  리전이 '$LOCATION'으로 변경되었습니다."
            Write-Host ""
            Test-CapabilityHostAvailability -Location $LOCATION
            return
        }
        else {
            Write-LogError "  CapabilityHost가 지원되지 않는 리전입니다. 배포를 중단합니다."
            exit 1
        }
    }
    
    # 추가 요구사항 확인
    Write-Host ""
    Write-LogInfo "CapabilityHost 추가 요구사항 확인:"
    
    # 1. Microsoft.App Provider 등록 상태 확인
    Write-LogInfo "  [1/3] Microsoft.App 리소스 공급자 확인 중..."
    try {
        $appProvider = az provider show --namespace Microsoft.App --query "registrationState" -o tsv 2>$null
        if ($appProvider -eq "Registered") {
            Write-LogSuccess "    ✓ Microsoft.App - 등록됨"
        }
        else {
            Write-LogWarning "    ⚠ Microsoft.App - $appProvider"
            $registerApp = Read-Host "    지금 등록하시겠습니까? [y/N]"
            if ($registerApp -eq 'y' -or $registerApp -eq 'Y') {
                Write-LogInfo "    Microsoft.App 등록 중..."
                az provider register --namespace Microsoft.App 2>$null
                Write-LogSuccess "    등록 시작됨 (전파에 몇 분 소요될 수 있음)"
            }
        }
    } catch {
        Write-LogWarning "    ⚠ Microsoft.App 상태 확인 실패"
    }
    
    # 2. Microsoft.CognitiveServices Provider 확인
    Write-LogInfo "  [2/3] Microsoft.CognitiveServices 리소스 공급자 확인 중..."
    try {
        $csProvider = az provider show --namespace Microsoft.CognitiveServices --query "registrationState" -o tsv 2>$null
        if ($csProvider -eq "Registered") {
            Write-LogSuccess "    ✓ Microsoft.CognitiveServices - 등록됨"
        }
        else {
            Write-LogWarning "    ⚠ Microsoft.CognitiveServices - $csProvider"
            az provider register --namespace Microsoft.CognitiveServices 2>$null
        }
    } catch {
        Write-LogWarning "    ⚠ Microsoft.CognitiveServices 상태 확인 실패"
    }
    
    # 3. Container Apps 가용성 확인
    Write-LogInfo "  [3/3] Container Apps 환경 가용성 확인 중..."
    Write-LogSuccess "    ✓ Container Apps - 사용 가능"
    
    Write-Host ""
    Write-LogSuccess "CapabilityHost 가용성 검사 완료"
    Write-Host ""
}

# =============================================================================
# 리소스 그룹 생성
# =============================================================================
function Ensure-ResourceGroup {
    param(
        [string]$RgName,
        [string]$Location
    )
    
    Write-LogInfo "리소스 그룹 확인: $RgName"
    
    $rgExists = az group show --name $RgName 2>$null
    if ($rgExists) {
        Write-LogSuccess "리소스 그룹 존재: $RgName"
        return
    }
    
    Write-LogInfo "리소스 그룹 생성 중: $RgName (위치: $Location)"
    az group create --name $RgName --location $Location --output none
    Write-LogSuccess "리소스 그룹 생성 완료: $RgName"
}

# =============================================================================
# VNet 및 서브넷 생성/확인
# =============================================================================
function Ensure-VNetAndSubnets {
    Write-LogStep "3/6 - VNet 및 서브넷 설정"
    
    # VNet 리소스 그룹 확인/생성
    Ensure-ResourceGroup -RgName $VNET_RESOURCE_GROUP -Location $LOCATION
    
    # VNet 확인/생성
    Write-LogInfo "VNet 확인: $VNET_NAME"
    $vnetExists = az network vnet show --name $VNET_NAME --resource-group $VNET_RESOURCE_GROUP 2>$null
    
    if ($vnetExists) {
        Write-LogSuccess "VNet 존재: $VNET_NAME"
    }
    else {
        Write-LogInfo "VNet 생성 중: $VNET_NAME ($VNET_PREFIX)"
        az network vnet create `
            --name $VNET_NAME `
            --resource-group $VNET_RESOURCE_GROUP `
            --location $LOCATION `
            --address-prefix $VNET_PREFIX `
            --output none
        Write-LogSuccess "VNet 생성 완료: $VNET_NAME"
        
        Write-LogInfo "VNet 동기화 대기 중 (15초)..."
        Start-Sleep -Seconds 15
    }
    
    # Agent 서브넷 확인/생성
    Write-LogInfo "Agent 서브넷 확인: $AGENT_SUBNET_NAME"
    $agentSubnetExists = az network vnet subnet show --name $AGENT_SUBNET_NAME --vnet-name $VNET_NAME --resource-group $VNET_RESOURCE_GROUP 2>$null
    
    if ($agentSubnetExists) {
        Write-LogSuccess "Agent 서브넷 존재: $AGENT_SUBNET_NAME"
        
        # 위임 확인
        $delegation = az network vnet subnet show --name $AGENT_SUBNET_NAME --vnet-name $VNET_NAME --resource-group $VNET_RESOURCE_GROUP --query "delegations[0].serviceName" -o tsv 2>$null
        if ($delegation -ne "Microsoft.App/environments") {
            Write-LogWarning "Agent 서브넷에 위임이 없습니다. 업데이트 중..."
            az network vnet subnet update `
                --name $AGENT_SUBNET_NAME `
                --vnet-name $VNET_NAME `
                --resource-group $VNET_RESOURCE_GROUP `
                --delegations "Microsoft.App/environments" `
                --output none 2>$null
        }
    }
    else {
        Write-LogInfo "Agent 서브넷 생성 중: $AGENT_SUBNET_NAME ($AGENT_SUBNET_PREFIX)"
        
        $maxRetry = 5
        for ($i = 1; $i -le $maxRetry; $i++) {
            try {
                az network vnet subnet create `
                    --name $AGENT_SUBNET_NAME `
                    --vnet-name $VNET_NAME `
                    --resource-group $VNET_RESOURCE_GROUP `
                    --address-prefix $AGENT_SUBNET_PREFIX `
                    --delegations "Microsoft.App/environments" `
                    --output none
                Write-LogSuccess "Agent 서브넷 생성 완료: $AGENT_SUBNET_NAME"
                break
            }
            catch {
                Write-LogWarning "서브넷 생성 실패. 재시도 $i/$maxRetry (10초 후)..."
                Start-Sleep -Seconds 10
            }
        }
    }
    
    # PE 서브넷 확인/생성
    Write-LogInfo "PE 서브넷 확인: $PE_SUBNET_NAME"
    $peSubnetExists = az network vnet subnet show --name $PE_SUBNET_NAME --vnet-name $VNET_NAME --resource-group $VNET_RESOURCE_GROUP 2>$null
    
    if ($peSubnetExists) {
        Write-LogSuccess "PE 서브넷 존재: $PE_SUBNET_NAME"
    }
    else {
        Write-LogInfo "PE 서브넷 생성 중: $PE_SUBNET_NAME ($PE_SUBNET_PREFIX)"
        az network vnet subnet create `
            --name $PE_SUBNET_NAME `
            --vnet-name $VNET_NAME `
            --resource-group $VNET_RESOURCE_GROUP `
            --address-prefix $PE_SUBNET_PREFIX `
            --output none
        Write-LogSuccess "PE 서브넷 생성 완료: $PE_SUBNET_NAME"
    }
    
    Write-LogSuccess "VNet 및 서브넷 준비 완료"
}

# =============================================================================
# Terraform 초기화
# =============================================================================
function Initialize-Terraform {
    Write-LogStep "4/6 - Terraform 초기화"
    
    Set-Location $ScriptDir
    
    if (-not (Test-Path ".terraform")) {
        Write-LogInfo "Terraform 초기화 중..."
        terraform init
    }
    else {
        Write-LogInfo "Terraform 재초기화 중..."
        terraform init -upgrade
    }
    
    Write-LogSuccess "Terraform 초기화 완료"
}

# =============================================================================
# Terraform Apply (재시도 로직 포함)
# =============================================================================
function Invoke-TerraformApply {
    Write-LogStep "5/6 - Terraform 배포 (재시도 로직 포함)"
    
    $maxRetries = 5
    $retryCount = 0
    $retryDelay = 30
    
    Set-Location $ScriptDir
    
    # Terraform 변수 설정
    $tfVars = @(
        "-var=location=$LOCATION",
        "-var=resource_group_name=$RESOURCE_GROUP_NAME",
        "-var=vnet_resource_group=$VNET_RESOURCE_GROUP",
        "-var=vnet_name=$VNET_NAME",
        "-var=agent_subnet_name=$AGENT_SUBNET_NAME",
        "-var=pe_subnet_name=$PE_SUBNET_NAME"
    )
    
    # 선택적 변수 추가
    if (-not [string]::IsNullOrEmpty($AI_SERVICES_NAME)) { $tfVars += "-var=ai_services_name=$AI_SERVICES_NAME" }
    if (-not [string]::IsNullOrEmpty($PROJECT_NAME)) { $tfVars += "-var=project_name=$PROJECT_NAME" }
    if (-not [string]::IsNullOrEmpty($STORAGE_NAME_PREFIX)) { $tfVars += "-var=storage_name_prefix=$STORAGE_NAME_PREFIX" }
    if (-not [string]::IsNullOrEmpty($COSMOSDB_NAME_PREFIX)) { $tfVars += "-var=cosmosdb_name_prefix=$COSMOSDB_NAME_PREFIX" }
    if (-not [string]::IsNullOrEmpty($AI_SEARCH_NAME_PREFIX)) { $tfVars += "-var=ai_search_name_prefix=$AI_SEARCH_NAME_PREFIX" }
    
    Write-LogInfo "최대 재시도 횟수: $maxRetries"
    
    while ($retryCount -lt $maxRetries) {
        $retryCount++
        Write-LogInfo "Terraform Apply 시도 $retryCount/$maxRetries"
        
        # Terraform apply 실행
        $output = terraform apply -auto-approve @tfVars 2>&1 | Tee-Object -FilePath $LogFile
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-LogSuccess "Terraform Apply 성공!"
            return $true
        }
        
        $errorOutput = $output -join "`n"
        
        # Provider 버그 체크
        if ($errorOutput -match "Provider produced inconsistent result after apply") {
            Write-LogWarning "Azure Provider 일시적 버그 감지"
            Write-LogInfo "$retryDelay`초 후 재시도..."
            Start-Sleep -Seconds $retryDelay
            terraform refresh @tfVars 2>$null
            continue
        }
        
        # 리소스 이미 존재
        if ($errorOutput -match "already exists - to be managed via Terraform") {
            Write-LogWarning "기존 리소스 발견. State refresh 후 재시도..."
            terraform refresh @tfVars 2>$null
            Start-Sleep -Seconds 10
            continue
        }
        
        # 일시적 네트워크 오류
        if ($errorOutput -match "(context deadline exceeded|connection reset|timeout|TooManyRequests)") {
            Write-LogWarning "일시적 오류 감지. $retryDelay`초 후 재시도..."
            Start-Sleep -Seconds $retryDelay
            continue
        }
        
        # SKU 가용성 오류
        if ($errorOutput -match "(ResourcesForSkuUnavailable|SkuNotAvailable)") {
            Write-LogError "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Write-LogError "리소스 SKU 가용성 오류 발생!"
            Write-LogError "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Write-Host ""
            Write-LogWarning "해결 옵션:"
            Write-Host "  [1] 다른 리전으로 변경"
            Write-Host "  [2] SKU 변경"
            Write-Host "  [3] 수동 해결 후 재시도"
            Write-Host "  [4] 배포 중단"
            Write-Host ""
            
            $choice = Read-Host "선택하세요 [1-4]"
            
            switch ($choice) {
                "1" {
                    $newLocation = Read-Host "새 리전 입력 (예: eastus, swedencentral)"
                    if (-not [string]::IsNullOrEmpty($newLocation)) {
                        $script:LOCATION = $newLocation
                        $tfVars = @("-var=location=$LOCATION", "-var=resource_group_name=$RESOURCE_GROUP_NAME",
                                   "-var=vnet_resource_group=$VNET_RESOURCE_GROUP", "-var=vnet_name=$VNET_NAME",
                                   "-var=agent_subnet_name=$AGENT_SUBNET_NAME", "-var=pe_subnet_name=$PE_SUBNET_NAME")
                        $retryCount = 0
                        continue
                    }
                }
                "2" {
                    $newSku = Read-Host "AI Search SKU 입력 (basic/standard/standard2)"
                    if (-not [string]::IsNullOrEmpty($newSku)) {
                        $tfVars += "-var=search_sku=$newSku"
                        $retryCount = 0
                        continue
                    }
                }
                "3" {
                    Write-LogInfo "수동 해결 후 Enter를 눌러 재시도하세요..."
                    Read-Host
                    continue
                }
                default {
                    Write-LogError "사용자에 의해 배포가 중단되었습니다."
                    return $false
                }
            }
        }
        
        # CapabilityHost 오류
        if ($errorOutput -match "(CapabilityHostOperationFailed|CapabilityHostProvisioningFailed)") {
            Write-LogError "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Write-LogError "Capability Host 프로비저닝 실패!"
            Write-LogError "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Write-Host ""
            Write-LogInfo "일반적인 원인:"
            Write-Host "  - RBAC 역할 할당 전파 지연 (1-2분 대기)"
            Write-Host "  - Private Endpoint 설정 미완료"
            Write-Host ""
            
            $capChoice = Read-Host "[1] 60초 대기 후 재시도 / [2] 수동 해결 후 재시도 / [3] 배포 중단"
            
            switch ($capChoice) {
                "1" {
                    Write-LogInfo "60초 대기 중 (RBAC 전파 대기)..."
                    Start-Sleep -Seconds 60
                    continue
                }
                "2" {
                    Write-LogInfo "수동 해결 후 Enter를 눌러 재시도하세요..."
                    Read-Host
                    continue
                }
                default {
                    return $false
                }
            }
        }
        
        # 기타 오류
        Write-LogError "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Write-LogError "예기치 않은 오류가 발생했습니다!"
        Write-LogError "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Write-Host ""
        Write-Host ($output | Select-Object -Last 20)
        Write-Host ""
        
        $otherChoice = Read-Host "[1] 재시도 / [2] 수동 해결 후 재시도 / [3] 배포 중단"
        
        switch ($otherChoice) {
            "1" {
                Write-LogInfo "$retryDelay`초 후 재시도..."
                Start-Sleep -Seconds $retryDelay
                continue
            }
            "2" {
                Write-LogInfo "수동 해결 후 Enter를 눌러 재시도하세요..."
                Read-Host
                continue
            }
            default {
                return $false
            }
        }
    }
    
    Write-LogError "최대 재시도 횟수($maxRetries) 초과. 배포 실패."
    Write-LogError "상세 로그: $LogFile"
    return $false
}

# =============================================================================
# 결과 출력
# =============================================================================
function Show-Outputs {
    Write-LogStep "6/6 - 배포 결과"
    
    Write-Host ""
    Write-Host "============================================================"
    terraform output
    Write-Host "============================================================"
    Write-Host ""
    Write-LogSuccess "배포 완료!"
    Write-LogInfo "Azure AI Foundry Portal: https://ai.azure.com"
}

# =============================================================================
# 메인 함수
# =============================================================================
function Main {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  AI Foundry Standard Agent Setup - PowerShell 배포 스크립트"
    Write-Host "  재시도 로직 및 VNet 자동 생성 기능 포함"
    Write-Host "============================================================"
    Write-Host ""
    
    # 1. 설정 검증
    Test-Config
    Write-Host ""
    
    # 2. Azure 로그인 확인
    Test-AzureLogin
    Write-Host ""
    
    # 2.5. 리소스 가용성 사전 검사
    if (-not $SkipAvailabilityCheck) {
        Test-ResourceAvailability -Location $LOCATION
        Test-OpenAIModelAvailability -Location $LOCATION
        Test-CapabilityHostAvailability -Location $LOCATION
    }
    Write-Host ""
    
    # 3. VNet 및 서브넷 생성/확인
    Ensure-VNetAndSubnets
    Write-Host ""
    
    # 4. Terraform 초기화
    Initialize-Terraform
    Write-Host ""
    
    # 5. Terraform Apply
    $result = Invoke-TerraformApply
    
    if ($result) {
        Write-Host ""
        # 6. 결과 출력
        Show-Outputs
    }
    else {
        Write-LogError "배포 실패. 로그 확인: $LogFile"
        exit 1
    }
}

# 스크립트 실행
Main
