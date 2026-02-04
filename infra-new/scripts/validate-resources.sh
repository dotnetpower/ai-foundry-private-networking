#!/bin/bash
# =============================================================================
# 리소스 검증 스크립트
# Capability Host 생성 전 모든 필수 조건 확인
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 -g <resource-group>"
    exit 1
}

while getopts "g:h" opt; do
    case $opt in
        g) RESOURCE_GROUP="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}Error: Resource Group 이름이 필요합니다.${NC}"
    usage
fi

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE} AI Foundry 리소스 검증${NC}"
echo -e "${BLUE}=============================================${NC}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
ERRORS=0

# =============================================================================
# 1. Resource Provider 확인
# =============================================================================
echo -e "\n${YELLOW}[1/7] Resource Provider 확인${NC}"

PROVIDERS=(
    "Microsoft.CognitiveServices"
    "Microsoft.Storage"
    "Microsoft.Search"
    "Microsoft.DocumentDB"
    "Microsoft.Network"
    "Microsoft.App"
)

for provider in "${PROVIDERS[@]}"; do
    status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null)
    if [ "$status" == "Registered" ]; then
        echo -e "  ${GREEN}✓ $provider${NC}"
    else
        echo -e "  ${RED}✗ $provider (상태: $status)${NC}"
        ((ERRORS++))
    fi
done

# =============================================================================
# 2. VNet 및 서브넷 확인
# =============================================================================
echo -e "\n${YELLOW}[2/7] VNet 및 서브넷 확인${NC}"

VNET=$(az network vnet list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null)
if [ -n "$VNET" ]; then
    echo -e "  ${GREEN}✓ VNet: $VNET${NC}"
    
    # Agent 서브넷 위임 확인
    AGENT_DELEGATION=$(az network vnet subnet list -g "$RESOURCE_GROUP" --vnet-name "$VNET" \
        --query "[?delegations[?serviceName=='Microsoft.App/environments']].name" -o tsv 2>/dev/null)
    
    if [ -n "$AGENT_DELEGATION" ]; then
        echo -e "  ${GREEN}✓ Agent 서브넷 (Microsoft.App/environments 위임): $AGENT_DELEGATION${NC}"
    else
        echo -e "  ${RED}✗ Agent 서브넷에 Microsoft.App/environments 위임이 없습니다${NC}"
        ((ERRORS++))
    fi
else
    echo -e "  ${RED}✗ VNet을 찾을 수 없습니다${NC}"
    ((ERRORS++))
fi

# =============================================================================
# 3. AI Services Account 확인
# =============================================================================
echo -e "\n${YELLOW}[3/7] AI Services Account 확인${NC}"

ACCOUNT=$(az cognitiveservices account list -g "$RESOURCE_GROUP" --query "[?kind=='AIServices'].name" -o tsv 2>/dev/null | head -1)
if [ -n "$ACCOUNT" ]; then
    echo -e "  ${GREEN}✓ AI Services Account: $ACCOUNT${NC}"
    
    # networkInjections 확인
    NETWORK_INJECTION=$(az rest --method GET \
        --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT}?api-version=2025-04-01-preview" \
        --query "properties.networkInjections" -o json 2>/dev/null)
    
    if [ "$NETWORK_INJECTION" != "null" ] && [ -n "$NETWORK_INJECTION" ]; then
        echo -e "  ${GREEN}✓ Network Injection 설정됨${NC}"
    else
        echo -e "  ${YELLOW}⚠ Network Injection이 설정되지 않았습니다${NC}"
    fi
else
    echo -e "  ${RED}✗ AI Services Account를 찾을 수 없습니다${NC}"
    ((ERRORS++))
fi

# =============================================================================
# 4. AI Project 확인
# =============================================================================
echo -e "\n${YELLOW}[4/7] AI Project 확인${NC}"

if [ -n "$ACCOUNT" ]; then
    PROJECT=$(az rest --method GET \
        --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT}/projects?api-version=2025-04-01-preview" \
        --query "value[0].name" -o tsv 2>/dev/null)
    
    if [ -n "$PROJECT" ]; then
        echo -e "  ${GREEN}✓ AI Project: $PROJECT${NC}"
        
        # Connections 확인
        CONNECTIONS=$(az rest --method GET \
            --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT}/projects/${PROJECT}/connections?api-version=2025-04-01-preview" \
            --query "value[].{name:name, category:properties.category}" -o table 2>/dev/null)
        
        echo -e "  ${BLUE}Connections:${NC}"
        echo "$CONNECTIONS" | sed 's/^/    /'
    else
        echo -e "  ${RED}✗ AI Project를 찾을 수 없습니다${NC}"
        ((ERRORS++))
    fi
fi

# =============================================================================
# 5. Private Endpoints 확인
# =============================================================================
echo -e "\n${YELLOW}[5/7] Private Endpoints 확인${NC}"

PE_LIST=$(az network private-endpoint list -g "$RESOURCE_GROUP" --query "[].{name:name, status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" -o table 2>/dev/null)
echo "$PE_LIST" | sed 's/^/  /'

PE_APPROVED=$(az network private-endpoint list -g "$RESOURCE_GROUP" \
    --query "length([?privateLinkServiceConnections[0].privateLinkServiceConnectionState.status=='Approved'])" -o tsv 2>/dev/null)

if [ "$PE_APPROVED" -ge 3 ]; then
    echo -e "  ${GREEN}✓ Private Endpoints 승인됨: $PE_APPROVED개${NC}"
else
    echo -e "  ${RED}✗ 승인된 Private Endpoint가 부족합니다 (필요: 3개 이상, 현재: $PE_APPROVED개)${NC}"
    ((ERRORS++))
fi

# =============================================================================
# 6. Private DNS Zones 확인
# =============================================================================
echo -e "\n${YELLOW}[6/7] Private DNS Zones 확인${NC}"

DNS_ZONES=(
    "privatelink.cognitiveservices.azure.com"
    "privatelink.openai.azure.com"
    "privatelink.services.ai.azure.com"
    "privatelink.blob.core.windows.net"
    "privatelink.documents.azure.com"
    "privatelink.search.windows.net"
)

for zone in "${DNS_ZONES[@]}"; do
    EXISTS=$(az network private-dns zone show -g "$RESOURCE_GROUP" -n "$zone" --query "name" -o tsv 2>/dev/null || echo "")
    if [ -n "$EXISTS" ]; then
        # VNet Link 확인
        LINKED=$(az network private-dns link vnet list -g "$RESOURCE_GROUP" -z "$zone" --query "length(@)" -o tsv 2>/dev/null)
        if [ "$LINKED" -ge 1 ]; then
            echo -e "  ${GREEN}✓ $zone (VNet 연결됨)${NC}"
        else
            echo -e "  ${YELLOW}⚠ $zone (VNet 연결 없음)${NC}"
        fi
    else
        echo -e "  ${RED}✗ $zone${NC}"
        ((ERRORS++))
    fi
done

# =============================================================================
# 7. RBAC 역할 할당 확인
# =============================================================================
echo -e "\n${YELLOW}[7/7] RBAC 역할 할당 확인${NC}"

if [ -n "$ACCOUNT" ] && [ -n "$PROJECT" ]; then
    PROJECT_SMI=$(az rest --method GET \
        --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT}/projects/${PROJECT}?api-version=2025-04-01-preview" \
        --query "identity.principalId" -o tsv 2>/dev/null)
    
    if [ -n "$PROJECT_SMI" ]; then
        echo -e "  ${GREEN}✓ Project SMI: $PROJECT_SMI${NC}"
        
        # Storage 역할 확인
        STORAGE=$(az storage account list -g "$RESOURCE_GROUP" --query "[0].id" -o tsv 2>/dev/null)
        if [ -n "$STORAGE" ]; then
            STORAGE_ROLES=$(az role assignment list --scope "$STORAGE" --assignee "$PROJECT_SMI" --query "[].roleDefinitionName" -o tsv 2>/dev/null)
            if echo "$STORAGE_ROLES" | grep -q "Blob"; then
                echo -e "  ${GREEN}✓ Storage RBAC 할당됨${NC}"
            else
                echo -e "  ${RED}✗ Storage RBAC 할당 필요${NC}"
                ((ERRORS++))
            fi
        fi
        
        # CosmosDB 역할 확인
        COSMOS=$(az cosmosdb list -g "$RESOURCE_GROUP" --query "[0].id" -o tsv 2>/dev/null)
        if [ -n "$COSMOS" ]; then
            COSMOS_ROLES=$(az role assignment list --scope "$COSMOS" --assignee "$PROJECT_SMI" --query "[].roleDefinitionName" -o tsv 2>/dev/null)
            if echo "$COSMOS_ROLES" | grep -q "Cosmos"; then
                echo -e "  ${GREEN}✓ CosmosDB RBAC 할당됨${NC}"
            else
                echo -e "  ${RED}✗ CosmosDB RBAC 할당 필요${NC}"
                ((ERRORS++))
            fi
        fi
        
        # Search 역할 확인
        SEARCH=$(az search service list -g "$RESOURCE_GROUP" --query "[0].id" -o tsv 2>/dev/null)
        if [ -n "$SEARCH" ]; then
            SEARCH_ROLES=$(az role assignment list --scope "$SEARCH" --assignee "$PROJECT_SMI" --query "[].roleDefinitionName" -o tsv 2>/dev/null)
            if echo "$SEARCH_ROLES" | grep -q "Search"; then
                echo -e "  ${GREEN}✓ AI Search RBAC 할당됨${NC}"
            else
                echo -e "  ${RED}✗ AI Search RBAC 할당 필요${NC}"
                ((ERRORS++))
            fi
        fi
    else
        echo -e "  ${RED}✗ Project SMI를 찾을 수 없습니다${NC}"
        ((ERRORS++))
    fi
fi

# =============================================================================
# 결과 요약
# =============================================================================
echo -e "\n${BLUE}=============================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ 모든 검증 통과! Capability Host 생성 준비 완료${NC}"
else
    echo -e "${RED}✗ $ERRORS개의 문제 발견. 위 항목을 확인하세요.${NC}"
fi
echo -e "${BLUE}=============================================${NC}"

exit $ERRORS
