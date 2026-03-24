#!/bin/bash
# =============================================================================
# Hosted Agent 배포 스크립트
# =============================================================================
# 인프라 배포 후 Docker 이미지 빌드 -> ACR 푸시 -> Agent 등록 -> Agent 시작
# Usage: ./scripts/deploy-hosted-agent.sh -g <resource-group> -i <image-name> -t <tag>
# =============================================================================

set -euo pipefail

# 기본값
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-aifoundry-hosted-dev}"
IMAGE_NAME="${IMAGE_NAME:-my-agent}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
AGENT_NAME="${AGENT_NAME:-my-agent}"
CPU="${CPU:-1}"
MEMORY="${MEMORY:-2Gi}"
MIN_REPLICAS="${MIN_REPLICAS:-0}"
MAX_REPLICAS="${MAX_REPLICAS:-2}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-.}"

# 인자 파싱
while getopts "g:i:t:n:c:m:d:" opt; do
  case $opt in
    g) RESOURCE_GROUP="$opt" ;;
    i) IMAGE_NAME="$OPTARG" ;;
    t) IMAGE_TAG="$OPTARG" ;;
    n) AGENT_NAME="$OPTARG" ;;
    c) CPU="$OPTARG" ;;
    m) MEMORY="$OPTARG" ;;
    d) DOCKERFILE_PATH="$OPTARG" ;;
    *) echo "Usage: $0 [-g resource-group] [-i image-name] [-t tag] [-n agent-name]" && exit 1 ;;
  esac
done

echo "=== Hosted Agent 배포 ==="
echo "리소스 그룹: ${RESOURCE_GROUP}"
echo "이미지: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Agent 이름: ${AGENT_NAME}"
echo ""

# 1. ACR 정보 확인
echo "[1/5] ACR 정보 확인..."
ACR_NAME=$(az acr list -g "${RESOURCE_GROUP}" --query "[0].name" -o tsv)
if [ -z "${ACR_NAME}" ]; then
  echo "ERROR: 리소스 그룹 ${RESOURCE_GROUP}에서 ACR을 찾을 수 없습니다."
  exit 1
fi
ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query "loginServer" -o tsv)
echo "  ACR: ${ACR_NAME} (${ACR_LOGIN_SERVER})"

# 2. Docker 이미지 빌드
echo ""
echo "[2/5] Docker 이미지 빌드 (linux/amd64)..."
docker build --platform linux/amd64 -t "${IMAGE_NAME}:${IMAGE_TAG}" "${DOCKERFILE_PATH}"
echo "  빌드 완료: ${IMAGE_NAME}:${IMAGE_TAG}"

# 3. ACR 로그인 및 푸시
echo ""
echo "[3/5] ACR 로그인 및 이미지 푸시..."
az acr login --name "${ACR_NAME}"
FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${FULL_IMAGE}"
docker push "${FULL_IMAGE}"
echo "  푸시 완료: ${FULL_IMAGE}"

# 4. Foundry 정보 확인
echo ""
echo "[4/5] Foundry Account/Project 정보 확인..."
ACCOUNT_NAME=$(az cognitiveservices account list -g "${RESOURCE_GROUP}" --query "[0].name" -o tsv)
PROJECT_NAME=$(az cognitiveservices account list -g "${RESOURCE_GROUP}" --query "[0].name" -o tsv | xargs -I {} az rest --method GET --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/{}/projects?api-version=2025-04-01-preview" --query "value[0].name" -o tsv)
ACCOUNT_ENDPOINT=$(az cognitiveservices account show --name "${ACCOUNT_NAME}" -g "${RESOURCE_GROUP}" --query "properties.endpoint" -o tsv)

echo "  Account: ${ACCOUNT_NAME}"
echo "  Project: ${PROJECT_NAME}"
echo "  Endpoint: ${ACCOUNT_ENDPOINT}"

# 5. Agent 등록은 Python SDK 사용 안내
echo ""
echo "[5/5] Agent 등록 및 시작"
echo ""
echo "=== Python SDK로 Agent 등록 ==="
echo "다음 Python 코드를 실행하여 Agent를 등록하세요:"
echo ""
cat << PYEOF
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import HostedAgentDefinition, ProtocolVersionRecord, AgentProtocol
from azure.identity import DefaultAzureCredential

client = AIProjectClient(
    endpoint="${ACCOUNT_ENDPOINT}/api/projects/${PROJECT_NAME}",
    credential=DefaultAzureCredential(),
    allow_preview=True,
)

agent = client.agents.create_version(
    agent_name="${AGENT_NAME}",
    definition=HostedAgentDefinition(
        container_protocol_versions=[
            ProtocolVersionRecord(protocol=AgentProtocol.RESPONSES, version="v1")
        ],
        cpu="${CPU}",
        memory="${MEMORY}",
        image="${FULL_IMAGE}",
        environment_variables={
            "AZURE_AI_PROJECT_ENDPOINT": "${ACCOUNT_ENDPOINT}/api/projects/${PROJECT_NAME}",
            "MODEL_NAME": "gpt-4o",
        },
    ),
)
print(f"Agent created: {agent.name} (version: {agent.version})")
PYEOF

echo ""
echo "=== Agent 시작 ==="
echo "az cognitiveservices agent start \\"
echo "  --account-name ${ACCOUNT_NAME} \\"
echo "  --project-name ${PROJECT_NAME} \\"
echo "  --name ${AGENT_NAME} --agent-version 1 \\"
echo "  --min-replicas ${MIN_REPLICAS} --max-replicas ${MAX_REPLICAS}"
echo ""
echo "=== 배포 정보 요약 ==="
echo "ACR 이미지: ${FULL_IMAGE}"
echo "Foundry Endpoint: ${ACCOUNT_ENDPOINT}"
echo "Project: ${PROJECT_NAME}"
