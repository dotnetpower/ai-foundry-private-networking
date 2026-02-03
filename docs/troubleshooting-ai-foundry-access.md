# AI Foundry 접속 문제 해결 가이드

## 문제 상황
vm-jb-win-krc에서 ai.azure.com 접속이 안 되는 경우

## 진단 단계

### 1. 기본 네트워크 연결 확인 (Jumpbox에서 PowerShell 실행)

```powershell
# 인터넷 연결 테스트
Test-NetConnection -ComputerName google.com -Port 443

# ai.azure.com 연결 테스트
Test-NetConnection -ComputerName ai.azure.com -Port 443

# AI Hub Private Endpoint 연결 테스트
Test-NetConnection -ComputerName de0fda5b-4fca-49f7-bf8f-4b028dbd7a2a.workspace.eastus.api.azureml.ms -Port 443
```

### 2. DNS 해석 확인 (Jumpbox에서 PowerShell 실행)

```powershell
# Public 도메인 테스트
nslookup ai.azure.com

# Private Endpoint DNS 테스트 - AI Hub
nslookup de0fda5b-4fca-49f7-bf8f-4b028dbd7a2a.workspace.eastus.api.azureml.ms

# Private Endpoint DNS 테스트 - Storage
nslookup staifoundry20260128.blob.core.windows.net

# 예상 결과: Private IP (10.0.1.x)가 반환되어야 함
```

### 3. Windows 방화벽 확인

```powershell
# 방화벽 상태 확인
Get-NetFirewallProfile | Select-Object Name, Enabled

# HTTPS 아웃바운드 규칙 확인
Get-NetFirewallRule -Direction Outbound | Where-Object {$_.Enabled -eq 'True' -and $_.Action -eq 'Block'}
```

### 4. 브라우저 캐시/쿠키 삭제

Edge 또는 Chrome에서:
1. 설정 → 개인정보 → 검색 데이터 삭제
2. 캐시된 이미지 및 파일 삭제
3. 쿠키 삭제 (선택적)

## 해결 방법

### 해결 방법 1: DNS 캐시 플러시

```powershell
# 관리자 권한으로 실행
ipconfig /flushdns
ipconfig /registerdns
```

### 해결 방법 2: 브라우저 직접 IP 테스트

ai.azure.com이 로드되지 않는 경우:
1. Edge InPrivate 모드 (Ctrl+Shift+N) 사용
2. 확장 프로그램 비활성화

### 해결 방법 3: hosts 파일 확인

```powershell
# hosts 파일 내용 확인
Get-Content C:\Windows\System32\drivers\etc\hosts

# 불필요한 항목이 있으면 제거
```

### 해결 방법 4: Azure DNS 사용 확인

```powershell
# 현재 DNS 서버 확인
Get-DnsClientServerAddress

# Azure VNet의 기본 DNS (168.63.129.16)를 사용해야 함
```

## 일반적인 원인 및 해결책

| 증상 | 원인 | 해결책 |
|------|------|--------|
| ai.azure.com 자체가 열리지 않음 | 인터넷 연결 문제 | NSG 아웃바운드 규칙 확인 |
| 로그인은 되지만 Hub/Project 접근 불가 | Private Endpoint DNS 문제 | DNS Zone VNet Link 확인 |
| "This site can't be reached" | DNS 해석 실패 | DNS 캐시 플러시, VNet DNS 설정 확인 |
| 매우 느리게 로드됨 | 네트워크 지연 | VNet Peering 상태 확인 |
| SSL 인증서 오류 | 프록시/방화벽 | 회사 프록시 설정 확인 |

## 추가 DNS Zone 확인

AI Foundry 전체 기능을 사용하려면 다음 Private DNS Zone이 모두 Korea Central VNet에 연결되어 있어야 합니다:

| DNS Zone | 용도 | 상태 |
|----------|------|------|
| privatelink.api.azureml.ms | AI Foundry API | ✅ 연결됨 |
| privatelink.notebooks.azure.net | Notebooks | ✅ 연결됨 |
| privatelink.blob.core.windows.net | Storage | 확인 필요 |
| privatelink.vaultcore.azure.net | Key Vault | 확인 필요 |
| privatelink.openai.azure.com | Azure OpenAI | 확인 필요 |

## Azure CLI로 VNet Link 확인 (로컬에서 실행)

```bash
# 모든 DNS Zone의 Korea Central VNet 링크 확인
for zone in privatelink.api.azureml.ms privatelink.notebooks.azure.net privatelink.blob.core.windows.net privatelink.vaultcore.azure.net privatelink.openai.azure.com; do
    echo "=== $zone ==="
    az network private-dns link vnet list --zone-name $zone --resource-group rg-aifoundry-20260128 --query "[?contains(virtualNetwork.id, 'jumpbox-krc')].name" -o tsv
done
```

## 문제가 지속되면

1. **Azure Portal에서 VM 재시작**
2. **Bastion을 통해 다시 연결**
3. **다른 브라우저 시도 (Edge, Chrome, Firefox)**
4. **Linux Jumpbox (vm-jumpbox-linux-krc)에서 curl 테스트**

```bash
# Linux Jumpbox에서 테스트
curl -I https://ai.azure.com
curl -I https://de0fda5b-4fca-49f7-bf8f-4b028dbd7a2a.workspace.eastus.api.azureml.ms
```
