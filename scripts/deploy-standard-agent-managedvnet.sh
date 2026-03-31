#!/usr/bin/env bash
# =============================================================================
# deploy-standard-agent-managedvnet.sh
# Azure Foundry Standard Agent - Managed VNet (Preview) 배포 스크립트
# =============================================================================
# 아키텍처:
#   Managed VNet (Azure 관리)   — Agent용 PE (자동)
#   Customer VNet (10.1.0.0/16) — PE 전용
#   Jumpbox VNet (10.2.0.0/16)  — VM 전용, Customer VNet과 피어링
#
# ⚠️ Preview 기능 — 프로덕션 비권장
# =============================================================================
set -euo pipefail

LOCATION="swedencentral"
ENV_NAME="dev"
DEPLOY_JUMPBOX=false
JUMPBOX_ADMIN_USER="azureuser"
JUMPBOX_ADMIN_PASSWORD=""

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

RG_NAME="rg-aif-mvnet-${LOCATION:0:3}-${ENV_NAME}"
NAME_PREFIX="aifmvnet-${ENV_NAME}"
SUFFIX=$(echo -n "${RG_NAME}" | md5sum | cut -c1-8)

# Resources
STORAGE_NAME="st${SUFFIX}"
COSMOS_NAME="cosmos-${SUFFIX}"
SEARCH_NAME="srch-${SUFFIX}"
ACCOUNT_NAME="cog-${SUFFIX}"
PROJECT_NAME="proj-${SUFFIX}"

# Network
CUSTOMER_VNET_NAME="vnet-${NAME_PREFIX}"
CUSTOMER_VNET_PREFIX="10.1.0.0/16"
PE_SUBNET_NAME="snet-privateendpoints"
PE_SUBNET_PREFIX="10.1.0.0/24"
JUMPBOX_VNET_NAME="vnet-${NAME_PREFIX}-jumpbox"
JUMPBOX_VNET_PREFIX="10.2.0.0/16"
JUMPBOX_SUBNET_NAME="snet-jumpbox"
JUMPBOX_SUBNET_PREFIX="10.2.0.0/24"

TAGS="Environment=${ENV_NAME} Project=AI-Foundry-ManagedVNet ManagedBy=AzCLI"

echo "============================================="
echo " Azure Foundry Managed VNet 배포 (Preview)"
echo "============================================="
echo " Location:    ${LOCATION}"
echo " Environment: ${ENV_NAME}"
echo " RG:          ${RG_NAME}"
echo " Suffix:      ${SUFFIX}"
echo " Jumpbox:     ${DEPLOY_JUMPBOX}"
echo "============================================="

# =============================================================================
# 0. Resource Providers + Preview Feature
# =============================================================================
echo ""
echo ">>> [0/7] Resource Providers + Preview Feature 등록..."
for ns in Microsoft.CognitiveServices Microsoft.Storage Microsoft.DocumentDB \
           Microsoft.Search Microsoft.Network Microsoft.App Microsoft.ContainerService; do
  az provider register --namespace "$ns" --wait 2>/dev/null || true
done

# Managed VNet Preview Feature
az feature register --namespace Microsoft.CognitiveServices --name AI.ManagedVnetPreview -o none 2>/dev/null || true
az provider register -n Microsoft.CognitiveServices --wait 2>/dev/null || true

# =============================================================================
# 1. Resource Group
# =============================================================================
echo ""
echo ">>> [1/7] Resource Group 생성: ${RG_NAME}"
az group create --name "$RG_NAME" --location "$LOCATION" --tags $TAGS -o none

# =============================================================================
# 2. Customer VNet (PE 전용) + Private DNS Zones
# =============================================================================
echo ""
echo ">>> [2/7] Customer VNet + NSG + Private DNS Zones..."

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

# Customer VNet
az network vnet create --name "$CUSTOMER_VNET_NAME" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --address-prefixes "$CUSTOMER_VNET_PREFIX" --tags $TAGS -o none

NSG_PE_ID=$(az network nsg show --name "nsg-${NAME_PREFIX}-pe" \
  --resource-group "$RG_NAME" --query id -o tsv)

az network vnet subnet create --name "$PE_SUBNET_NAME" \
  --resource-group "$RG_NAME" --vnet-name "$CUSTOMER_VNET_NAME" \
  --address-prefixes "$PE_SUBNET_PREFIX" \
  --network-security-group "$NSG_PE_ID" \
  --private-endpoint-network-policies Disabled -o none

CUSTOMER_VNET_ID=$(az network vnet show --name "$CUSTOMER_VNET_NAME" \
  --resource-group "$RG_NAME" --query id -o tsv)
PE_SUBNET_ID=$(az network vnet subnet show --name "$PE_SUBNET_NAME" \
  --resource-group "$RG_NAME" --vnet-name "$CUSTOMER_VNET_NAME" --query id -o tsv)

SUB_ID=$(az account show --query id -o tsv)

# Private DNS Zones
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
    --name "link-${NAME_PREFIX}" --resource-group "$RG_NAME" \
    --zone-name "$zone" --virtual-network "$CUSTOMER_VNET_ID" \
    --registration-enabled false -o none
done

# =============================================================================
# 3. Dependent Resources (publicNetworkAccess: Disabled)
# =============================================================================
echo ""
echo ">>> [3/7] Storage + Cosmos DB + AI Search..."

az storage account create --name "$STORAGE_NAME" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --sku Standard_ZRS --kind StorageV2 --access-tier Hot \
  --min-tls-version TLS1_2 --https-only true \
  --allow-blob-public-access false --allow-shared-key-access false \
  --public-network-access Disabled --default-action Deny --bypass AzureServices \
  --tags $TAGS -o none

STORAGE_ID=$(az storage account show --name "$STORAGE_NAME" --resource-group "$RG_NAME" --query id -o tsv)

az cosmosdb create --name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" --locations "regionName=${LOCATION}" \
  --kind GlobalDocumentDB --default-consistency-level Session \
  --capabilities EnableServerless \
  --enable-automatic-failover false --enable-multiple-write-locations false \
  --public-network-access DISABLED --network-acl-bypass AzureServices \
  --tags $TAGS -o none

az cosmosdb update --name "$COSMOS_NAME" --resource-group "$RG_NAME" \
  --disable-key-based-metadata-write-access true -o none

COSMOS_ID=$(az cosmosdb show --name "$COSMOS_NAME" --resource-group "$RG_NAME" --query id -o tsv)

az cosmosdb sql database create --account-name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" --name agentdb -o none

az cosmosdb sql container create --account-name "$COSMOS_NAME" \
  --resource-group "$RG_NAME" --database-name agentdb --name threads \
  --partition-key-path "/threadId" -o none

az search service create --name "$SEARCH_NAME" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --sku standard --partition-count 1 --replica-count 1 \
  --public-network-access disabled \
  --auth-options aadOrApiKey --aad-auth-failure-mode http401WithBearerChallenge \
  --semantic-search standard --identity-type SystemAssigned \
  --tags $TAGS -o none

SEARCH_ID=$(az search service show --name "$SEARCH_NAME" --resource-group "$RG_NAME" --query id -o tsv)

# =============================================================================
# 4. AI Foundry Account (Managed VNet) + Models + Project + Connections
# =============================================================================
echo ""
echo ">>> [4/7] AI Foundry Account (Managed VNet) + Models + Project..."

az rest --method PUT \
  --url "https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}?api-version=2025-04-01-preview" \
  --body "{
    \"location\": \"${LOCATION}\",
    \"kind\": \"AIServices\",
    \"sku\": { \"name\": \"S0\" },
    \"identity\": { \"type\": \"SystemAssigned\" },
    \"tags\": { \"Environment\": \"${ENV_NAME}\", \"Project\": \"AI-Foundry-ManagedVNet\" },
    \"properties\": {
      \"customSubDomainName\": \"${ACCOUNT_NAME}\",
      \"publicNetworkAccess\": \"Disabled\",
      \"networkAcls\": { \"defaultAction\": \"Deny\", \"bypass\": \"AzureServices\" },
      \"disableLocalAuth\": false,
      \"allowProjectManagement\": true,
      \"networkInjections\": [{
        \"scenario\": \"agent\",
        \"useMicrosoftManagedNetwork\": true
      }]
    }
  }" -o none

echo "  Account 프로비저닝 대기..."
az resource wait --ids "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT_NAME}" \
  --custom "properties.provisioningState=='Succeeded'" --timeout 600 2>/dev/null || sleep 30

ACCOUNT_ID=$(az cognitiveservices account show --name "$ACCOUNT_NAME" --resource-group "$RG_NAME" --query id -o tsv)
ACCOUNT_PRINCIPAL=$(az cognitiveservices account show --name "$ACCOUNT_NAME" --resource-group "$RG_NAME" --query "identity.principalId" -o tsv)

# Managed Network 생성 (AllowInternetOutbound)
echo "  Managed Network 생성..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/managedNetworks/default?api-version=2025-10-01-preview" \
  --body "{\"properties\":{\"managedNetwork\":{\"IsolationMode\":\"AllowInternetOutbound\",\"managedNetworkKind\":\"V2\"}}}" -o none

echo "  Managed Network 프로비저닝 대기..."
sleep 30

# Enterprise Network Connection Approver (Outbound Rules 생성 전 필요)
NETWORK_CONNECTION_APPROVER="b556d68e-0be0-4f35-a333-ad7ee1ce17ea"
az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role "$NETWORK_CONNECTION_APPROVER" --scope "$STORAGE_ID" -o none 2>/dev/null || true
az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role "$NETWORK_CONNECTION_APPROVER" --scope "$COSMOS_ID" -o none 2>/dev/null || true
az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role "$NETWORK_CONNECTION_APPROVER" --scope "$SEARCH_ID" -o none 2>/dev/null || true

# Managed Network Outbound Rules (PE)
echo "  Outbound Rules 생성 (Storage/Cosmos/Search)..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/managedNetworks/default/outboundRules/storage-rule?api-version=2025-10-01-preview" \
  --body "{\"properties\":{\"type\":\"PrivateEndpoint\",\"destination\":{\"serviceResourceId\":\"${STORAGE_ID}\",\"subresourceTarget\":\"blob\",\"sparkEnabled\":false,\"sparkStatus\":\"Inactive\"},\"category\":\"UserDefined\"}}" -o none

az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/managedNetworks/default/outboundRules/cosmos-rule?api-version=2025-10-01-preview" \
  --body "{\"properties\":{\"type\":\"PrivateEndpoint\",\"destination\":{\"serviceResourceId\":\"${COSMOS_ID}\",\"subresourceTarget\":\"Sql\",\"sparkEnabled\":false,\"sparkStatus\":\"Inactive\"},\"category\":\"UserDefined\"}}" -o none

az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/managedNetworks/default/outboundRules/search-rule?api-version=2025-10-01-preview" \
  --body "{\"properties\":{\"type\":\"PrivateEndpoint\",\"destination\":{\"serviceResourceId\":\"${SEARCH_ID}\",\"subresourceTarget\":\"searchService\",\"sparkEnabled\":false,\"sparkStatus\":\"Inactive\"},\"category\":\"UserDefined\"}}" -o none

echo "  Outbound Rules 프로비저닝 대기..."
sleep 30

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

echo "  Project 생성..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}?api-version=2025-04-01-preview" \
  --body "{
    \"location\": \"${LOCATION}\",
    \"identity\": { \"type\": \"SystemAssigned\" },
    \"kind\": \"Project\",
    \"sku\": { \"name\": \"S0\" },
    \"properties\": {}
  }" -o none

echo "  Project 프로비저닝 대기..."
sleep 30

PROJECT_PRINCIPAL=$(az rest --method GET \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}?api-version=2025-04-01-preview" \
  --query "identity.principalId" -o tsv)

echo "  Connections 생성..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/connections/storage-connection?api-version=2025-04-01-preview" \
  --body "{\"properties\":{\"category\":\"AzureStorageAccount\",\"target\":\"https://${STORAGE_NAME}.blob.core.windows.net\",\"authType\":\"AAD\",\"metadata\":{\"ApiType\":\"azure\",\"AccountName\":\"${STORAGE_NAME}\",\"ContainerName\":\"agents-data\",\"ResourceId\":\"${STORAGE_ID}\"}}}" -o none

az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/connections/cosmos-connection?api-version=2025-04-01-preview" \
  --body "{\"properties\":{\"category\":\"CosmosDB\",\"target\":\"https://${COSMOS_NAME}.documents.azure.com:443/\",\"authType\":\"AAD\",\"metadata\":{\"ApiType\":\"azure\",\"AccountName\":\"${COSMOS_NAME}\",\"DatabaseName\":\"agentdb\",\"ResourceId\":\"${COSMOS_ID}\"}}}" -o none

az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/connections/search-connection?api-version=2025-04-01-preview" \
  --body "{\"properties\":{\"category\":\"CognitiveSearch\",\"target\":\"https://${SEARCH_NAME}.search.windows.net\",\"authType\":\"AAD\",\"metadata\":{\"ApiType\":\"azure\",\"ResourceId\":\"${SEARCH_ID}\"}}}" -o none

# =============================================================================
# 5. Customer VNet Private Endpoints
# =============================================================================
echo ""
echo ">>> [5/7] Customer VNet Private Endpoints..."

az network private-endpoint create --name "pe-${NAME_PREFIX}-foundry" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$CUSTOMER_VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$ACCOUNT_ID" \
  --group-id account --connection-name "plsc-foundry" --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-foundry" --resource-group "$RG_NAME" --name default \
  --zone-name cognitiveservices \
  --private-dns-zone "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com" -o none

az network private-endpoint dns-zone-group add \
  --endpoint-name "pe-${NAME_PREFIX}-foundry" --resource-group "$RG_NAME" --name default \
  --zone-name openai \
  --private-dns-zone "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com" -o none

az network private-endpoint dns-zone-group add \
  --endpoint-name "pe-${NAME_PREFIX}-foundry" --resource-group "$RG_NAME" --name default \
  --zone-name servicesai \
  --private-dns-zone "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com" -o none

az network private-endpoint create --name "pe-${NAME_PREFIX}-storage-blob" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$CUSTOMER_VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id blob --connection-name "plsc-storage-blob" --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-storage-blob" --resource-group "$RG_NAME" --name default \
  --zone-name blob \
  --private-dns-zone "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" -o none

az network private-endpoint create --name "pe-${NAME_PREFIX}-storage-file" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$CUSTOMER_VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id file --connection-name "plsc-storage-file" --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-storage-file" --resource-group "$RG_NAME" --name default \
  --zone-name file \
  --private-dns-zone "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net" -o none

az network private-endpoint create --name "pe-${NAME_PREFIX}-cosmos" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$CUSTOMER_VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$COSMOS_ID" \
  --group-id Sql --connection-name "plsc-cosmos" --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-cosmos" --resource-group "$RG_NAME" --name default \
  --zone-name cosmosdb \
  --private-dns-zone "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com" -o none

az network private-endpoint create --name "pe-${NAME_PREFIX}-search" \
  --resource-group "$RG_NAME" --location "$LOCATION" \
  --vnet-name "$CUSTOMER_VNET_NAME" --subnet "$PE_SUBNET_NAME" \
  --private-connection-resource-id "$SEARCH_ID" \
  --group-id searchService --connection-name "plsc-search" --tags $TAGS -o none

az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${NAME_PREFIX}-search" --resource-group "$RG_NAME" --name default \
  --zone-name search \
  --private-dns-zone "/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net" -o none

# =============================================================================
# 6. RBAC + Capability Host
# =============================================================================
echo ""
echo ">>> [6/7] RBAC + Capability Host..."

STORAGE_BLOB_DATA_OWNER="b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
STORAGE_BLOB_DATA_CONTRIBUTOR="ba92f5b4-2d11-453d-a403-e96b0029c9fe"
STORAGE_QUEUE_DATA_CONTRIBUTOR="974c5e8b-45b9-4653-ba55-5f855dd0fb88"
COSMOS_DB_OPERATOR="230815da-be43-4aae-9cb4-875f7bd000aa"
SEARCH_INDEX_DATA_CONTRIBUTOR="8ebe5a00-799e-43f5-93ac-243d3dce84a7"
SEARCH_SERVICE_CONTRIBUTOR="7ca78c08-252a-4471-8644-bb5ff32d4ba0"
COGNITIVE_SERVICES_OPENAI_CONTRIBUTOR="a001fd3d-188f-4b5d-821b-7da978bf7442"
COSMOS_BUILTIN_DATA_CONTRIBUTOR="00000000-0000-0000-0000-000000000002"

for ROLE in "$STORAGE_BLOB_DATA_OWNER" "$STORAGE_BLOB_DATA_CONTRIBUTOR"; do
  az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$STORAGE_ID" -o none 2>/dev/null || true
  az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$STORAGE_ID" -o none 2>/dev/null || true
done

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$STORAGE_QUEUE_DATA_CONTRIBUTOR" --scope "$STORAGE_ID" -o none 2>/dev/null || true

for ROLE in "$COSMOS_DB_OPERATOR"; do
  az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$COSMOS_ID" -o none 2>/dev/null || true
  az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$COSMOS_ID" -o none 2>/dev/null || true
done

for ROLE in "$SEARCH_INDEX_DATA_CONTRIBUTOR" "$SEARCH_SERVICE_CONTRIBUTOR"; do
  az role assignment create --assignee-object-id "$ACCOUNT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$SEARCH_ID" -o none 2>/dev/null || true
  az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$SEARCH_ID" -o none 2>/dev/null || true
done

az role assignment create --assignee-object-id "$PROJECT_PRINCIPAL" --assignee-principal-type ServicePrincipal --role "$COGNITIVE_SERVICES_OPENAI_CONTRIBUTOR" --scope "$ACCOUNT_ID" -o none 2>/dev/null || true

echo "  Cosmos DB Data Plane RBAC..."
az cosmosdb sql role assignment create --account-name "$COSMOS_NAME" --resource-group "$RG_NAME" \
  --role-definition-id "$COSMOS_BUILTIN_DATA_CONTRIBUTOR" --principal-id "$ACCOUNT_PRINCIPAL" --scope "/" -o none 2>/dev/null || true
az cosmosdb sql role assignment create --account-name "$COSMOS_NAME" --resource-group "$RG_NAME" \
  --role-definition-id "$COSMOS_BUILTIN_DATA_CONTRIBUTOR" --principal-id "$PROJECT_PRINCIPAL" --scope "/" -o none 2>/dev/null || true

echo "  Account Capability Host 생성..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/capabilityHosts/caphost-account?api-version=2025-04-01-preview" \
  --body "{\"properties\":{\"capabilityHostKind\":\"Agents\"}}" -o none

echo "  Account Capability Host 프로비저닝 대기..."
sleep 90

echo "  Project Capability Host 생성..."
az rest --method PUT \
  --url "https://management.azure.com${ACCOUNT_ID}/projects/${PROJECT_NAME}/capabilityHosts/caphost-agent?api-version=2025-04-01-preview" \
  --body "{\"properties\":{\"capabilityHostKind\":\"Agents\",\"vectorStoreConnections\":[\"search-connection\"],\"storageConnections\":[\"storage-connection\"],\"threadStorageConnections\":[\"cosmos-connection\"]}}" -o none

echo "  Project Capability Host 프로비저닝 대기..."
sleep 60

# =============================================================================
# 7. Jumpbox VNet + Peering + DNS Links + VM (Optional)
# =============================================================================
if $DEPLOY_JUMPBOX; then
  echo ""
  echo ">>> [7/7] Jumpbox VNet + Peering + VM..."

  if [[ -z "$JUMPBOX_ADMIN_PASSWORD" ]]; then
    echo "ERROR: --jumpbox-password 파라미터가 필요합니다."
    exit 1
  fi

  # Jumpbox NSG
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

  # Jumpbox VNet
  az network vnet create --name "$JUMPBOX_VNET_NAME" \
    --resource-group "$RG_NAME" --location "$LOCATION" \
    --address-prefixes "$JUMPBOX_VNET_PREFIX" --tags $TAGS -o none

  NSG_JB_ID=$(az network nsg show --name "nsg-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --query id -o tsv)

  az network vnet subnet create --name "$JUMPBOX_SUBNET_NAME" \
    --resource-group "$RG_NAME" --vnet-name "$JUMPBOX_VNET_NAME" \
    --address-prefixes "$JUMPBOX_SUBNET_PREFIX" \
    --network-security-group "$NSG_JB_ID" \
    --default-outbound false -o none

  JUMPBOX_VNET_ID=$(az network vnet show --name "$JUMPBOX_VNET_NAME" \
    --resource-group "$RG_NAME" --query id -o tsv)
  JUMPBOX_SUBNET_ID=$(az network vnet subnet show --name "$JUMPBOX_SUBNET_NAME" \
    --resource-group "$RG_NAME" --vnet-name "$JUMPBOX_VNET_NAME" --query id -o tsv)

  # VNet Peering: Customer ↔ Jumpbox (양방향)
  echo "  VNet Peering: Customer ↔ Jumpbox..."
  az network vnet peering create --name peer-customer-to-jumpbox \
    --resource-group "$RG_NAME" --vnet-name "$CUSTOMER_VNET_NAME" \
    --remote-vnet "$JUMPBOX_VNET_ID" \
    --allow-vnet-access true --allow-forwarded-traffic true -o none

  az network vnet peering create --name peer-jumpbox-to-customer \
    --resource-group "$RG_NAME" --vnet-name "$JUMPBOX_VNET_NAME" \
    --remote-vnet "$CUSTOMER_VNET_ID" \
    --allow-vnet-access true --allow-forwarded-traffic true -o none

  # DNS Zone → Jumpbox VNet Link
  echo "  DNS Zone → Jumpbox VNet Link..."
  for zone in "${DNS_ZONES[@]}"; do
    az network private-dns link vnet create \
      --name "link-${NAME_PREFIX}-jumpbox" --resource-group "$RG_NAME" \
      --zone-name "$zone" --virtual-network "$JUMPBOX_VNET_ID" \
      --registration-enabled false -o none
  done

  # Public IP + NIC + VM
  az network public-ip create --name "pip-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --location "$LOCATION" \
    --sku Standard --allocation-method Static --version IPv4 --tags $TAGS -o none

  az network nic create --name "nic-${NAME_PREFIX}-windows" \
    --resource-group "$RG_NAME" --location "$LOCATION" \
    --subnet "$JUMPBOX_SUBNET_ID" \
    --public-ip-address "pip-${NAME_PREFIX}-jumpbox" --tags $TAGS -o none

  az vm create --name "vm-${NAME_PREFIX}-win" \
    --resource-group "$RG_NAME" --location "$LOCATION" \
    --nics "nic-${NAME_PREFIX}-windows" \
    --image MicrosoftWindowsDesktop:windows-11:win11-24h2-pro:latest \
    --size Standard_B2ms --computer-name "jb-mvnet" \
    --admin-username "$JUMPBOX_ADMIN_USER" \
    --admin-password "$JUMPBOX_ADMIN_PASSWORD" \
    --os-disk-size-gb 128 --storage-sku Standard_LRS \
    --tags $TAGS -o none

  JUMPBOX_PIP=$(az network public-ip show --name "pip-${NAME_PREFIX}-jumpbox" \
    --resource-group "$RG_NAME" --query ipAddress -o tsv)
  echo "  Jumpbox Public IP: ${JUMPBOX_PIP}"
fi

# =============================================================================
# 완료
# =============================================================================
echo ""
echo "============================================="
echo " 배포 완료! (Managed VNet — Preview)"
echo "============================================="
echo " Resource Group:   ${RG_NAME}"
echo " Customer VNet:    ${CUSTOMER_VNET_NAME} (${CUSTOMER_VNET_PREFIX})"
echo " Account:          ${ACCOUNT_NAME}"
echo " Project:          ${PROJECT_NAME}"
echo " Storage:          ${STORAGE_NAME}"
echo " Cosmos DB:        ${COSMOS_NAME}"
echo " AI Search:        ${SEARCH_NAME}"
if $DEPLOY_JUMPBOX; then
  echo " Jumpbox VNet:     ${JUMPBOX_VNET_NAME} (${JUMPBOX_VNET_PREFIX})"
  echo " Jumpbox IP:       ${JUMPBOX_PIP}"
fi
echo ""
echo " Foundry Portal:   https://ai.azure.com"
echo "============================================="
echo ""
echo "삭제 시:"
echo "  az group delete --name ${RG_NAME} --yes"
echo "  az cognitiveservices account purge --name ${ACCOUNT_NAME} --resource-group ${RG_NAME} --location ${LOCATION}"
