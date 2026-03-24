# Hosted Agent Setup

> **Private Networking 미지원 (2026년 3월 기준)**
>
> Hosted Agent는 현재 **Preview** 단계이며, **Private Networking을 지원하지 않습니다.**
> 네트워크 격리가 필요한 환경에서는 [Standard Agent Setup](../standard/)을 사용하세요.
>
> - `publicNetworkAccess: Enabled` **필수**
> - VNet / Private Endpoint 연동 **불가**
> - Capability Host 설정 시 `enablePublicHostingEnvironment: true` **필수**
>
> 출처: [Microsoft Learn - Hosted Agents Limitations](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/hosted-agents#private-networking-support)

## 개요

컨테이너화된 에이전트 코드를 Azure Foundry Agent Service에서 관리형으로 실행합니다.

### 배포되는 리소스

| 리소스 | 용도 |
|--------|------|
| Foundry Account (AIServices) | AI 서비스 호스팅 |
| Foundry Project | 에이전트 프로젝트 |
| Model Deployments | GPT-4o, text-embedding-ada-002 |
| Capability Host (Account 수준) | Hosted Agent 실행 환경 |
| Azure Container Registry | 에이전트 컨테이너 이미지 저장 |
| Application Insights | OpenTelemetry 트레이스/메트릭 |
| Log Analytics Workspace | 로그 수집 |

### 아키텍처

```
┌──────────────────────────────────────────────────────────┐
│              Hosted Agent (Public Only)                   │
│                                                          │
│  Foundry Account ──── Capability Host                    │
│       │               (enablePublicHostingEnvironment)   │
│       │                                                  │
│  Foundry Project ──── Managed Identity ──── ACR (Pull)   │
│       │                                                  │
│  Model Deployments    Application Insights               │
│  (GPT-4o, Embedding)  (OpenTelemetry)                    │
│                                                          │
│  [!] VNet / Private Endpoint 연동 불가                    │
└──────────────────────────────────────────────────────────┘
```

## 배포

### 1. 인프라 배포 (Bicep)

```bash
cd infra-foundry-new/hosted

az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

### 2. Docker 이미지 빌드 및 ACR 푸시

```bash
# ACR 이름 확인
ACR_NAME=$(az acr list -g rg-aifoundry-hosted-dev --query "[0].name" -o tsv)

# 반드시 linux/amd64 플랫폼으로 빌드
docker build --platform linux/amd64 -t my-agent:v1 .

# ACR 로그인 및 푸시
az acr login --name $ACR_NAME
docker tag my-agent:v1 ${ACR_NAME}.azurecr.io/my-agent:v1
docker push ${ACR_NAME}.azurecr.io/my-agent:v1
```

### 3. Agent 등록 (Python SDK)

```python
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import HostedAgentDefinition, ProtocolVersionRecord, AgentProtocol
from azure.identity import DefaultAzureCredential

client = AIProjectClient(
    endpoint="https://<account>.services.ai.azure.com/api/projects/<project>",
    credential=DefaultAzureCredential(),
    allow_preview=True,
)

agent = client.agents.create_version(
    agent_name="my-agent",
    definition=HostedAgentDefinition(
        container_protocol_versions=[
            ProtocolVersionRecord(protocol=AgentProtocol.RESPONSES, version="v1")
        ],
        cpu="1",
        memory="2Gi",
        image="<acr>.azurecr.io/my-agent:v1",
        environment_variables={
            "AZURE_AI_PROJECT_ENDPOINT": "<project-endpoint>",
            "MODEL_NAME": "gpt-4o",
        },
    ),
)
```

### 4. Agent 시작

```bash
az cognitiveservices agent start \
  --account-name <account> --project-name <project> \
  --name my-agent --agent-version 1 \
  --min-replicas 0 --max-replicas 2
```

## Preview 제한사항

| 제한 | 값 |
|------|-----|
| 구독당 Hosted Agent Foundry 리소스 | 100개 |
| Foundry 리소스당 Hosted Agent | 200개 |
| 최대 min_replica | 2 |
| 최대 max_replica | 5 |
| **Private Networking** | **미지원** |
