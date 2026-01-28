# 오류 해결 요약

> **최종 업데이트**: 2026년 1월 28일

## 배포 상태: 성공

모든 주요 리소스가 성공적으로 배포되었습니다.

### 배포 완료된 리소스

| 리소스 | 이름 | 상태 |
|--------|------|------|
| Resource Group | `rg-aifoundry-20260128` | 배포 완료 |
| VNet (East US) | `vnet-aifoundry` | 배포 완료 |
| VNet (Korea Central) | `vnet-jumpbox-krc` | 배포 완료 |
| VNet Peering | Korea Central ↔ East US | 배포 완료 |
| Azure OpenAI | `aoai-aifoundry` | 배포 완료 |
| GPT-4o 배포 | `gpt-4o` | 배포 완료 |
| Embedding 배포 | `text-embedding-ada-002` | 배포 완료 |
| AI Search | `srch-aifoundry-7kkykgt6` | 배포 완료 |
| Storage Account | `staifoundry20260128` | 배포 완료 |
| Container Registry | `acraifoundryb658f2ug` | 배포 완료 |
| Key Vault | `kv-aif-e8txcj4l` | 배포 완료 |
| Windows Jumpbox | `vm-jb-win-krc` | 배포 완료 |
| Linux Jumpbox | `vm-jumpbox-linux-krc` | 배포 완료 |
| Bastion | `bastion-jumpbox-krc` | 배포 완료 |
| Log Analytics | `log-aifoundry` | 배포 완료 |
| Application Insights | `appi-aifoundry` | 배포 완료 |
| Private Endpoints | 7개 | 배포 완료 |
| Private DNS Zones | 9개 | 배포 완료 |

---

## 해결된 오류

### 1. GPT-4o 배포 중복 오류

**증상**: `A resource with the ID ... already exists`

**원인**: 동일한 이름의 GPT-4o 배포가 이미 존재

**해결 방법**: Terraform import 명령으로 기존 리소스 가져오기
```bash
terraform import module.cognitive_services.azurerm_cognitive_deployment.gpt4o \
  "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.CognitiveServices/accounts/{account}/deployments/gpt-4o"
```

### 2. Jumpbox VM 크기 문제

**증상**: `Standard_B2ms`가 East US에서 사용 불가

**원인**: 구독 할당량 제한 또는 리전 용량 부족

**해결 방법**: Korea Central 리전에 Jumpbox 배포 (jumpbox-krc 모듈 사용)

### 3. Key Vault 이름 충돌

**증상**: Key Vault 이름이 이미 사용 중

**원인**: Soft-delete된 Key Vault 또는 전역 이름 충돌

**해결 방법**: `random_string` suffix 사용으로 고유 이름 생성 (`kv-aif-e8txcj4l`)

### 4. Storage Container 권한 오류

**증상**: `403 AuthorizationFailure`

**원인**: RBAC 역할 전파 지연 (약 30-60초 소요)

**해결 방법**: 
- 재배포 시 RBAC 전파 완료 후 자동 해결
- 또는 `time_sleep` 리소스 추가

### 5. Terraform Output Sensitive 오류

**증상**: `Output refers to sensitive values`

**원인**: sensitive 값을 참조하는 output에 `sensitive = true` 누락

**해결 방법**: `outputs.tf`에서 해당 output에 `sensitive = true` 추가

---

## 알려진 제한사항

### AI Foundry Hub/Project 배포

- `azurerm_machine_learning_workspace`는 Hub/Project kind를 지원하지 않음
- `azapi_resource`를 사용하여 배포해야 함
- 프라이빗 엔드포인트는 Hub 레벨에서 구성

### 멀티 리전 구성

- AI Foundry 핵심 리소스: East US (Azure OpenAI 모델 가용성)
- Jumpbox VMs: Korea Central (낮은 지연시간)
- VNet Peering으로 두 리전 연결 필요

---

## 문제 해결 팁

### Terraform State 동기화 문제
```bash
terraform refresh -var-file="environments/dev/terraform.tfvars"
```

### 리소스 재생성이 필요한 경우
```bash
terraform taint module.{module_name}.{resource_name}
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### 전체 재배포
```bash
terraform destroy -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```
