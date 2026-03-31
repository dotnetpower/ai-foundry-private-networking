#!/usr/bin/env bash
# =============================================================================
# deploy-standard-agent.sh
# Azure Foundry Standard Agent - Private Networking 단일 배포 스크립트
# =============================================================================
# Bicep 템플릿(infra-foundry-new/standard/basic/)과 동일한 구성을
# az cli 명령어로 재현합니다.
#
# 리소스: VNet, NSG, Subnets, Private DNS Zones, Storage, Cosmos DB,
#         AI Search, AI Foundry Account/Project, Private Endpoints,
#         Capability Host, RBAC, (선택) Jumpbox VM
#
# 사용법:
#   chmod +x scripts/deploy-standard-agent.sh
#   ./scripts/deploy-standard-agent.sh [--location swedencentral] [--env dev] [--jumpbox]
# =============================================================================
set -euo pipefail

# =============================================================================
# 파라미터 파싱
# =============================================================================
LOCATION="swedencentral"
ENV_NAME="dev"
DEPLOY_JUMPBOX=false
JUMPBOX_ADMIN_USER="azureuser"
JUMPBOX_ADMIN_PASSWORD="Fndry!Ag3nt#2026xQ"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --location) LOCATION="$2"; shift 2 ;;
    --env) ENV_NAME="$2"; shift 2 ;;
    --jumpbox) DEPLOY_JUMPBOX=true; shift ;;
    --jumpbox-password) JUMPBOX_ADMIN_PASSWORD="$2"; shift 2 ;;
    --jumpbox-user) JUMPBOX_ADMIN_USER="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# =============================================================================
# 변수 설정
# =============================================================================
RG_NAME="rg-aif-new-${LOCATION:0:3}-${ENV_NAME}"
NAME_PREFIX="aifoundry-${ENV_NAME}"
SUFFIX=$(echo -n "${RG_NAME}" | md5sum | cut -c1-8)

# Network
VNET_NAME="vnet-${NAME_PREFIX}"
VNET_PREFIX="10.0.0.0/16"
AGENT_SUBNET_NAME="snet-agent"
AGENT_SUBNET_PREFIX="10.0.0.0/24"
PE_SUBNET_NAME="snet-privateendpoints"
PE_SUBNET_PREFIX="10.0.1.0/24"
JUMPBOX_SUBNET_NAME="snet-jumpbox"
JUMPBOX_SUBNET_PREFIX="10.0.2.0/24"

# Resources
STORAGE_NAME="st${SUFFIX}"
COSMOS_NAME="cosmos-${SUFFIX}"
SEARCH_NAME="srch-${SUFFIX}"
ACCOUNT_NAME="cog-${SUFFIX}"
PROJECT_NAME="proj-${SUFFIX}"
IDENTITY_NAME="id-${SUFFIX}"

# Tags
TAGS="Environment=${ENV_NAME} Project=AI-Foundry-Private-Networking ManagedBy=AzCLI"

echo "============================================="
echo " Azure Foundry Standard Agent 배포"
echo "============================================="
echo " Location:    ${LOCATION}"
echo " Environment: ${ENV_NAME}"
echo " RG:          ${RG_NAME}"
echo " Suffix:      ${SUFFIX}"
echo " Jumpbox:     ${DEPLOY_JUMPBOX}"
echo "============================================="

# =============================================================================
# 0. Resource Providers 등록
# =============================================================================
echo ""
echo ">>> [0/10] Resource Providers 등록..."
for ns in Microsoft.CognitiveServices Microsoft.Storage Microsoft.DocumentDB \
           Microsoft.Search Microsoft.Network Microsoft.App Microsoft.ContainerService; do
  az provider register --namespace "$ns" --wait 2>/dev/null || true
done

# =============================================================================
# 1. Resource Group
# =============================================================================
echo ""
echo ">>> [1/10] Resource Group 생성: ${RG_NAME}"
az group create --name "$RG_NAME" --location "$LOCATION" --tags $TAGS -o none

# =============================================================================
# 2. NSG 생성
# =============================================================================
echo ""
echo ">>> [2/10] NSG 생성..."

# Agent NSG
az network nsg create --name "nsg-${NAME_PREFIX}-agent" \
  --resource-group "$RG_NAME" --location "$LOCATION" --tags $TAGS -o none

az network nsg rule create --nsg-name "nsg-${NAME_PREFIX}-agent" \
  --resource-group "$RG_NAME" --name AllowHTTPSInbound \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-port-ranges '*' --destination-port-ranges 443 \
  --source-address-prefixes VirtualNetwork --destination-address-prefixes '*' -o none

az network nsg rule create --nsg-name "nsg-${NAME_PREFIX}-agent" \
  --resource-group "$RG_NAME" --name DenyAllInbound \
  --priority 4096 --direction Inbound --access Deny --protocol '*' \
  --source-port-ranges '*' --destination-port-ranges '*' \
  --source-address-prefixes '*' --destination-address-prefixes '*' -o none

# PE NSG
az network nsg create --name "nsg-${NAME_PREFIX}-pe" \
  --resource-group "$RG_NAME" --location "$LOCATION" --tags $TAGS -o none

az network nsg rule create --nsg-name "nsg-${NAME_PREFIX}-pe" \
  --resource-group "$RG_NAME" --name AllowHTTPSInbound \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-port-ranges '*' --destination-port-ranges 443 \
  --source-address-prefixes VirtualNetwork --destination-address-prefixes '*' -o none

az network nsg rule create --nsg-name "nsg-${NAME_PREFIX}-pe" \
  --resource-group "$RG_NAME" --name DenyAllInbound \
  --priority 4096 --direction Inbound --access Deny --protocol '*' \
  --source-port-ranges '*' --destination-port-ranges '*' \
  --source-address-prefixes '*' --destination-address-prefixes '*' -o none

# Jumpbox NSG (optional)
if $DEPLOY_JUMPBOX; then
  az network nsg create --name "nsg-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --location "$LOCATION" --tags $TAGS -o none

  az network nsg rule create --nsg-name "nsg-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --name AllowRDP \
    --priority 100 --direction Inbound --access Allow --protocol Tcp \
    --source-port-ranges '*' --destination-port-ranges 3389 \
    --source-address-prefixes VirtualNetwork --destination-address-prefixes '*' -o none

  az network nsg rule create --nsg-name "nsg-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --name DenyAllInbound \
    --priority 4095 --direction Inbound --access Deny --protocol '*' \
    --source-port-ranges '*' --destination-port-ranges '*' \
    --source-address-prefixes '*' --destination-address-prefixes '*' -o none
fi

# =============================================================================
# 3. VNet + Subnets
# =============================================================================
echo ""
echo ">>> [3/10] VNet + Subnets 생성..."

az network vnet create --name "$VNET_NAME" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --address-prefixes "$VNET_PREFIX" --tags $TAGS -o none

# Agent Subnet (with Microsoft.App/environments delegation)
NSG_AGENT_ID=$(az network nsg show --name "nsg-${NAME_PREFIX}-agent" \
  --resource-group "$RG_NAME" --query id -o tsv)

az network vnet subnet create --name "$AGENT_SUBNET_NAME" \
  --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" \
  --address-prefixes "$AGENT_SUBNET_PREFIX" \
  --network-security-group "$NSG_AGENT_ID" \
  --delegations Microsoft.App/environments \
  --disable-private-endpoint-network-policies true -o none

# PE Subnet
NSG_PE_ID=$(az network nsg show --name "nsg-${NAME_PREFIX}-pe" \
  --resource-group "$RG_NAME" --query id -o tsv)

az network vnet subnet create --name "$PE_SUBNET_NAME" \
  --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" \
  --address-prefixes "$PE_SUBNET_PREFIX" \
  --network-security-group "$NSG_PE_ID" \
  --disable-private-endpoint-network-policies true -o none

# Jumpbox Subnet (optional)
if $DEPLOY_JUMPBOX; then
  NSG_JB_ID=$(az network nsg show --name "nsg-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --query id -o tsv)

  az network vnet subnet create --name "$JUMPBOX_SUBNET_NAME" \
    --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" \
    --address-prefixes "$JUMPBOX_SUBNET_PREFIX" \
    --network-security-group "$NSG_JB_ID" \
    --default-outbound false -o none
fi

AGENT_SUBNET_ID=$(az network vnet subnet show --name "$AGENT_SUBNET_NAME" \
  --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" --query id -o tsv)
PE_SUBNET_ID=$(az network vnet subnet show --name "$PE_SUBNET_NAME" \
  --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" --query id -o tsv)
VNET_ID=$(az network vnet show --name "$VNET_NAME" \
  --resource-group "$RG_NAME" --query id -o tsv)

# =============================================================================
# 4. Private DNS Zones + VNet Links
# =============================================================================
echo ""
echo ">>> [4/10] Private DNS Zones 생성..."

DNS_ZONES=(
  "privatelink.cognitiveservices.azure.com"
  "privatelink.openai.azure.com"
  "privatelink.services.ai.azure.com"
  "privatelink.search.windows.net"
  "privatelink.documents.azure.com"
  "privatelink.blob.core.windows.net"
  "privatelink.file.core.windows.net"
)

for zone in "${DNS_ZONES[@]}"; do
  az network private-dns zone create --name "$zone" \
    --resource-group "$RG_NAME" --tags $TAGS -o none

  az network private-dns link vnet create \
    --name "link-${NAME_PREFIX}" \
    --resource-group "$RG_NAME" \
    --zone-name "$zone" \
    --virtual-network "$VNET_ID" \
    --registration-enabled false -o none
done

# =============================================================================
# 5. Storage Account
# =============================================================================
echo ""
echo ">>> [5/10] Storage Account 생성: ${STORAGE_NAME}"

az storage account create --name "$STORAGE_NAME" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --sku Standard_ZRS --kind StorageV2 --access-tier Hot \
  --min-tls-version TLS1_2 --https-only true \
  --allow-blob-public-access false --allow-shared-key-access false \
  --public-network-access Disabled --default-action Deny --bypass AzureServices \
  --tags $TAGS -o none

STORAGE_ID=$(az storage account show --name "$STORAGE_NAME" \
  --resource-group "$RG_NAME" --query id -o tsv)

# Blob containers (컨테이너 생성은 PE 후 VNet 내에서 or RBAC 이후 —
# Capability Host가 agents-data 컨테이너를 자동 생성하므로 생략 가능)

# =============================================================================
# 6. Cosmos DB
# =============================================================================
echo ""
echo ">>> [6/10] Cosmos DB 생성: ${COSMOS_NAME}"

az cosmosdb create --name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" --locations "regionName=${LOCATION}" \
  --kind GlobalDocumentDB \
  --default-consistency-level Session \
  --capabilities EnableServerless \
  --enable-automatic-failover false \
  --enable-multiple-write-locations false \
  --public-network-access DISABLED \
  --network-acl-bypass AzureServices \
  --tags $TAGS -o none

# disable local auth (AAD only)
az cosmosdb update --name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" \
  --disable-key-based-metadata-write-access true -o none

COSMOS_ID=$(az cosmosdb show --name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" --query id -o tsv)

# Cosmos DB - agentdb database + threads container
az cosmosdb sql database create --account-name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" --name agentdb -o none

az cosmosdb sql container create --account-name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" --database-name agentdb --name threads \
  --partition-key-path "/threadId" -o none

# =============================================================================
# 7. AI Search
# =============================================================================
echo ""
echo ">>> [7/10] AI Search 생성: ${SEARCH_NAME}"

az search service create --name "$SEARCH_NAME" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --sku standard --partition-count 1 --replica-count 1 \
  --public-network-access disabled \
  --auth-options aadOrApiKey \
  --aad-auth-failure-mode http401WithBearerChallenge \
  --semantic-search standard \
  --identity-type SystemAssigned \
  --tags $TAGS -o none

SEARCH_ID=$(az search service show --name "$SEARCH_NAME" \
  --resource-group "$RG_NAME" --query id -o tsv)

# =============================================================================
# 8. AI Foundry Account + Project + Models
# =============================================================================
echo ""
echo ">>> [8/10] AI Foundry Account + Project + Models..."

# Account (with networkInjections)
az rest --method PUT \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}?api-version=2025-04-01-preview" \
  --body "{
    \"location\": \"${LOCATION}\",
    \"kind\": \"AIServices\",
    \"sku\": { \"name\": \"S0\" },
    \"identity\": { \"type\": \"SystemAssigned\" },
    \"tags\": { \"Environment\": \"${ENV_NAME}\", \"Project\": \"AI-Foundry-Private-Networking\" },
    \"properties\": {
      \"customSubDomainName\": \"${ACCOUNT_NAME}\",
      \"publicNetworkAccess\": \"Disabled\",
      \"networkAcls\": { \"defaultAction\": \"Deny\", \"bypass\": \"AzureServices\" },
      \"disableLocalAuth\": false,
      \"allowProjectManagement\": true,
      \"networkInjections\": [{
        \"scenario\": \"agent\",
        \"subnetArmId\": \"${AGENT_SUBNET_ID}\",
        \"useMicrosoftManagedNetwork\": false
      }]
    }
  }" -o none

# 프로비저닝 대기
echo "  Account 프로비저닝 대기..."
az resource wait --ids "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}" \
  --custom "properties.provisioningState=='Succeeded'" --timeout 600 2>/dev/null || sleep 30

ACCOUNT_ID=$(az cognitiveservices account show --name "$ACCOUNT_NAME" \
  --resource-group "$RG_NAME" --query id -o tsv)
ACCOUNT_PRINCIPAL=$(az cognitiveservices account show --name "$ACCOUNT_NAME" \
  --resource-group "$RG_NAME" --query "identity.principalId" -o tsv)

# Model Deployments (sequential - Azure 제약)
echo "  모델 배포: gpt-4o..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/deployments/gpt-4o?api-version=2025-04-01-preview" \
  --body "{
    \"sku\": { \"name\": \"GlobalStandard\", \"capacity\": 10 },
    \"properties\": {
      \"model\": { \"format\": \"OpenAI\", \"name\": \"gpt-4o\", \"version\": \"2024-11-20\" },
      \"raiPolicyName\": \"Microsoft.DefaultV2\"
    }
  }" -o none
sleep 10

echo "  모델 배포: text-embedding-3-large..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/deployments/text-embedding-3-large?api-version=2025-04-01-preview" \
  --body "{
    \"sku\": { \"name\": \"GlobalStandard\", \"capacity\": 10 },
    \"properties\": {
      \"model\": { \"format\": \"OpenAI\", \"name\": \"text-embedding-3-large\", \"version\": \"1\" }
    }
  }" -o none
sleep 10

# Project
echo "  Project 생성: ${PROJECT_NAME}..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}?api-version=2025-04-01-preview" \
  --body "{
    \"location\": \"${LOCATION}\",
    \"identity\": { \"type\": \"SystemAssigned\" },
    \"kind\": \"Project\",
    \"sku\": { \"name\": \"S0\" },
    \"tags\": { \"Environment\": \"${ENV_NAME}\" },
    \"properties\": {}
  }" -o none

echo "  Project 프로비저닝 대기..."
sleep 30

PROJECT_PRINCIPAL=$(az rest --method GET \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}?api-version=2025-04-01-preview" \
  --query "identity.principalId" -o tsv)

# Connections
echo "  Connections 생성..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/connections/storage-connection?api-version=2025-04-01-preview" \
  --body "{
    \"properties\": {
      \"category\": \"AzureStorageAccount\",
      \"target\": \"https://${STORAGE_NAME}.blob.core.windows.net\",
      \"authType\": \"AAD\",
      \"metadata\": {
        \"ApiType\": \"azure\",
        \"AccountName\": \"${STORAGE_NAME}\",
        \"ContainerName\": \"agents-data\",
        \"ResourceId\": \"${STORAGE_ID}\"
      }
    }
  }" -o none

az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/connections/cosmos-connection?api-version=2025-04-01-preview" \
  --body "{
    \"properties\": {
      \"category\": \"CosmosDB\",
      \"target\": \"https://${COSMOS_NAME}.documents.azure.com:443/\",
      \"authType\": \"AAD\",
      \"metadata\": {
        \"ApiType\": \"azure\",
        \"AccountName\": \"${COSMOS_NAME}\",
        \"DatabaseName\": \"agentdb\",
        \"ResourceId\": \"${COSMOS_ID}\"
      }
    }
  }" -o none

az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/connections/search-connection?api-version=2025-04-01-preview" \
  --body "{
    \"properties\": {
      \"category\": \"CognitiveSearch\",
      \"target\": \"https://${SEARCH_NAME}.search.windows.net\",
      \"authType\": \"AAD\",
      \"metadata\": {
        \"ApiType\": \"azure\",
        \"ResourceId\": \"${SEARCH_ID}\"
      }
    }
  }" -o none

# =============================================================================
# 9. Private Endpoints
# =============================================================================
echo ""
echo ">>> [9/10] Private Endpoints 생성..."

# Foundry Account PE
az network private-endpoint create --name "pe-${NAME_PREFIX}-foundry" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$ACCOUNT_ID" \
  --group-id account --connection-name "plsc-foundry" \
  --tags $TAGS -o none

# Foundry DNS zone groups (3 zones)
az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-foundry" \
  --resource-group "$RG_NAME" --name default \
  --zone-name cognitiveservices \
  --private-dns-zone "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com" -o none

az network private-endpoint dns-zone-group add \
  --endpoint-name "pe-${NAME_PREFIX}-foundry" \
  --resource-group "$RG_NAME" --name default \
  --zone-name openai \
  --private-dns-zone "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com" -o none

az network private-endpoint dns-zone-group add \
  --endpoint-name "pe-${NAME_PREFIX}-foundry" \
  --resource-group "$RG_NAME" --name default \
  --zone-name servicesai \
  --private-dns-zone "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com" -o none

# Storage Blob PE
az network private-endpoint create --name "pe-${NAME_PREFIX}-storage-blob" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id blob --connection-name "plsc-storage-blob" \
  --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-storage-blob" \
  --resource-group "$RG_NAME" --name default \
  --zone-name blob \
  --private-dns-zone "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" -o none

# Storage File PE
az network private-endpoint create --name "pe-${NAME_PREFIX}-storage-file" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id file --connection-name "plsc-storage-file" \
  --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-storage-file" \
  --resource-group "$RG_NAME" --name default \
  --zone-name file \
  --private-dns-zone "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net" -o none

# Cosmos DB PE
az network private-endpoint create --name "pe-${NAME_PREFIX}-cosmos" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$COSMOS_ID" \
  --group-id Sql --connection-name "plsc-cosmos" \
  --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-cosmos" \
  --resource-group "$RG_NAME" --name default \
  --zone-name cosmosdb \
  --private-dns-zone "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com" -o none

# AI Search PE
az network private-endpoint create --name "pe-${NAME_PREFIX}-search" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$SEARCH_ID" \
  --group-id searchService --connection-name "plsc-search" \
  --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-search" \
  --resource-group "$RG_NAME" --name default \
  --zone-name search \
  --private-dns-zone "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net" -o none

# =============================================================================
# 10. RBAC + Capability Host
# =============================================================================
echo ""
echo ">>> [10/10] RBAC + Capability Host..."

# Role IDs
STORAGE_BLOB_DATA_OWNER="b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
STORAGE_BLOB_DATA_CONTRIBUTOR="ba92f5b4-2d11-453d-a403-e96b0029c9fe"
STORAGE_QUEUE_DATA_CONTRIBUTOR="974c5e8b-45b9-4653-ba55-5f855dd0fb88"
COSMOS_DB_OPERATOR="230815da-be43-4aae-9cb4-875f7bd000aa"
SEARCH_INDEX_DATA_CONTRIBUTOR="8ebe5a00-799e-43f5-93ac-243d3dce84a7"
SEARCH_SERVICE_CONTRIBUTOR="7ca78c08-252a-4471-8644-bb5ff32d4ba0"
COGNITIVE_SERVICES_OPENAI_CONTRIBUTOR="a001fd3d-188f-4b5d-821b-7da978bf7442"

# Account System Identity RBAC
echo "  RBAC: Account System Identity..."
az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$STORAGE_BLOB_DATA_OWNER" --scope "$STORAGE_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$STORAGE_BLOB_DATA_CONTRIBUTOR" --scope "$STORAGE_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$COSMOS_DB_OPERATOR" --scope "$COSMOS_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$SEARCH_INDEX_DATA_CONTRIBUTOR" --scope "$SEARCH_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$SEARCH_SERVICE_CONTRIBUTOR" --scope "$SEARCH_ID" -o none 2>/dev/null || true

# Project System Identity RBAC
echo "  RBAC: Project System Identity..."
az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$STORAGE_BLOB_DATA_OWNER" --scope "$STORAGE_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$STORAGE_BLOB_DATA_CONTRIBUTOR" --scope "$STORAGE_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$STORAGE_QUEUE_DATA_CONTRIBUTOR" --scope "$STORAGE_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$COSMOS_DB_OPERATOR" --scope "$COSMOS_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$SEARCH_INDEX_DATA_CONTRIBUTOR" --scope "$SEARCH_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$SEARCH_SERVICE_CONTRIBUTOR" --scope "$SEARCH_ID" -o none 2>/dev/null || true

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal \
  --role "$COGNITIVE_SERVICES_OPENAI_CONTRIBUTOR" --scope "$ACCOUNT_ID" -o none 2>/dev/null || true

# Cosmos DB Data Plane RBAC (Built-in Data Contributor)
# Azure RBAC의 Cosmos DB Operator는 관리 플레인 전용.
# 데이터 접근에는 Cosmos DB 자체 데이터 플레인 역할이 필수.
COSMOS_BUILTIN_DATA_CONTRIBUTOR="00000000-0000-0000-0000-000000000002"

echo "  RBAC: Cosmos DB Data Plane (Account)..."
az cosmosdb sql role assignment create \
  --account-name "$COSMOS_NAME" --resource-group "$RG_NAME" \
  --role-definition-id "$COSMOS_BUILTIN_DATA_CONTRIBUTOR" \
  --principal-id "$ACCOUNT_PRINCIPAL" \
  --scope "/" -o none 2>/dev/null || true

echo "  RBAC: Cosmos DB Data Plane (Project)..."
az cosmosdb sql role assignment create \
  --account-name "$COSMOS_NAME" --resource-group "$RG_NAME" \
  --role-definition-id "$COSMOS_BUILTIN_DATA_CONTRIBUTOR" \
  --principal-id "$PROJECT_PRINCIPAL" \
  --scope "/" -o none 2>/dev/null || true

# Capability Host
echo "  Capability Host 생성..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/capabilityHosts/caphost-agent?api-version=2025-04-01-preview" \
  --body "{
    \"properties\": {
      \"capabilityHostKind\": \"Agents\",
      \"vectorStoreConnections\": [\"search-connection\"],
      \"storageConnections\": [\"storage-connection\"],
      \"threadStorageConnections\": [\"cosmos-connection\"]
    }
  }" -o none

echo "  Capability Host 프로비저닝 대기..."
sleep 60

# =============================================================================
# 11. Jumpbox (Optional)
# =============================================================================
if $DEPLOY_JUMPBOX; then
  echo ""
  echo ">>> [Jumpbox] Windows VM 배포..."

  if [[ -z "$JUMPBOX_ADMIN_PASSWORD" ]]; then
    echo "ERROR: --jumpbox-password 파라미터가 필요합니다."
    exit 1
  fi

  JUMPBOX_SUBNET_ID=$(az network vnet subnet show --name "$JUMPBOX_SUBNET_NAME" \
    --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" --query id -o tsv)

  # Public IP
  az network public-ip create --name "pip-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --location "$LOCATION" \
    --sku Standard --allocation-method Static --version IPv4 \
    --tags $TAGS -o none

  # NIC
  az network nic create --name "nic-${NAME_PREFIX}-windows" \
    --resource-group "$RG_NAME" --location "$LOCATION" \
    --subnet "$JUMPBOX_SUBNET_ID" \
    --public-ip-address "pip-${NAME_PREFIX}-jumpbox" \
    --tags $TAGS -o none

  # VM
  az vm create --name "vm-${NAME_PREFIX}-win" \
    --resource-group "$RG_NAME" --location "$LOCATION" \
    --nics "nic-${NAME_PREFIX}-windows" \
    --image MicrosoftWindowsDesktop:windows-11:win11-24h2-pro:latest \
    --size Standard_B2ms \
    --computer-name "jumpbox-win" \
    --admin-username "$JUMPBOX_ADMIN_USER" \
    --admin-password "$JUMPBOX_ADMIN_PASSWORD" \
    --os-disk-size-gb 128 \
    --storage-sku Standard_LRS \
    --tags $TAGS -o none

  JUMPBOX_PIP=$(az network public-ip show --name "pip-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --query ipAddress -o tsv)
  echo "  Jumpbox Public IP: ${JUMPBOX_PIP}"
fi

# =============================================================================
# 완료 요약
# =============================================================================
echo ""
echo "============================================="
echo " 배포 완료!"
echo "============================================="
echo " Resource Group:  ${RG_NAME}"
echo " VNet:            ${VNET_NAME}"
echo " Account:         ${ACCOUNT_NAME}"
echo " Project:         ${PROJECT_NAME}"
echo " Storage:         ${STORAGE_NAME}"
echo " Cosmos DB:       ${COSMOS_NAME}"
echo " AI Search:       ${SEARCH_NAME}"
if $DEPLOY_JUMPBOX; then
  echo " Jumpbox IP:      ${JUMPBOX_PIP}"
fi
echo ""
echo " Foundry Portal:  https://ai.azure.com"
echo "============================================="
echo ""
echo "삭제 시:"
echo "  az group delete --name ${RG_NAME} --yes"
echo "  az cognitiveservices account purge --name ${ACCOUNT_NAME} --resource-group ${RG_NAME} --location ${LOCATION}"
