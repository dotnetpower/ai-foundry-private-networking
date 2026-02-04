#!/bin/bash
# 기존 Azure 리소스를 Terraform state로 import하는 스크립트

set -e

cd /home/dotnetpower/dev/ai-foundry-private-networking/infra

SUBSCRIPTION="b052302c-4c8d-49a4-aa2f-9d60a7301a80"
RG="rg-aifoundry-20260128"
VARS="-var-file=environments/dev/terraform.tfvars"

echo "=== Terraform 리소스 Import 시작 ==="

# Random strings (이미 생성된 값으로 import)
echo "1. Random Strings import..."
terraform import $VARS 'module.security.random_string.suffix' "e8txcj4l" 2>/dev/null || true
terraform import $VARS 'module.storage.random_string.suffix' "b658f2ug" 2>/dev/null || true
terraform import $VARS 'module.cognitive_services.random_string.suffix' "7kkykgt6" 2>/dev/null || true
terraform import $VARS 'module.cognitive_services.random_string.openai_suffix' "jnucxsub" 2>/dev/null || true
terraform import $VARS 'module.apim.random_string.suffix' "zj85lf" 2>/dev/null || true

# Networking
echo "2. Networking 리소스 import..."
terraform import $VARS 'module.networking.azurerm_subnet.ai_foundry' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/vnet-aifoundry/subnets/snet-aifoundry" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_subnet.jumpbox' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/vnet-aifoundry/subnets/snet-jumpbox" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_network_security_group.ai_foundry' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/networkSecurityGroups/nsg-aifoundry" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_network_security_group.jumpbox' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/networkSecurityGroups/nsg-jumpbox" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_subnet_network_security_group_association.jumpbox' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/vnet-aifoundry/subnets/snet-jumpbox" 2>/dev/null || true

# Private DNS Zones
echo "3. Private DNS Zones import..."
terraform import $VARS 'module.networking.azurerm_private_dns_zone.azureml' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone.notebooks' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone.blob' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone.file' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone.vault' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone.cogservices' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone.openai' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone.apim' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.azure-api.net" 2>/dev/null || true

# Private DNS Zone VNet Links
echo "4. Private DNS Zone VNet Links import..."
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.azureml' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms/virtualNetworkLinks/link-azureml" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.notebooks' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net/virtualNetworkLinks/link-notebooks" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.blob' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net/virtualNetworkLinks/link-blob" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.file' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net/virtualNetworkLinks/link-file" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.vault' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/virtualNetworkLinks/link-vault" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.cogservices' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com/virtualNetworkLinks/link-cogservices" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.openai' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com/virtualNetworkLinks/link-openai" 2>/dev/null || true
terraform import $VARS 'module.networking.azurerm_private_dns_zone_virtual_network_link.apim' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.azure-api.net/virtualNetworkLinks/link-apim" 2>/dev/null || true

# Security (Key Vault)
echo "5. Security 리소스 import..."
terraform import $VARS 'module.security.azurerm_user_assigned_identity.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-aifoundry" 2>/dev/null || true
terraform import $VARS 'module.security.azurerm_key_vault.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/kv-aif-e8txcj4l" 2>/dev/null || true
terraform import $VARS 'module.security.azurerm_key_vault_access_policy.current_user' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/kv-aif-e8txcj4l/objectId/e26ace5a-a825-4c0a-b5a0-af95461250ab" 2>/dev/null || true
terraform import $VARS 'module.security.azurerm_key_vault_access_policy.managed_identity' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/kv-aif-e8txcj4l/objectId/ef2f7372-cb67-4407-ad8e-6c8f15e1c24a" 2>/dev/null || true

# Storage
echo "6. Storage 리소스 import..."
terraform import $VARS 'module.storage.azurerm_storage_account.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/staifoundry20260128" 2>/dev/null || true
terraform import $VARS 'module.storage.azurerm_role_assignment.storage_blob_contributor' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/staifoundry20260128/providers/Microsoft.Authorization/roleAssignments/ec5170dd-18df-5484-65f1-7d681ed5b36f" 2>/dev/null || true
terraform import $VARS 'module.storage.azurerm_role_assignment.storage_account_contributor' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/staifoundry20260128/providers/Microsoft.Authorization/roleAssignments/411ce160-7680-7e69-a7c4-e11417e6718d" 2>/dev/null || true
terraform import $VARS 'module.storage.azapi_resource.container_data' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/staifoundry20260128/blobServices/default/containers/data" 2>/dev/null || true
terraform import $VARS 'module.storage.azapi_resource.container_models' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/staifoundry20260128/blobServices/default/containers/models" 2>/dev/null || true
terraform import $VARS 'module.storage.azurerm_container_registry.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.ContainerRegistry/registries/acraifoundryb658f2ug" 2>/dev/null || true
terraform import $VARS 'module.storage.azurerm_private_dns_zone.acr' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io" 2>/dev/null || true

# Cognitive Services
echo "7. Cognitive Services import..."
terraform import $VARS 'module.cognitive_services.azurerm_cognitive_account.openai' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/aoai-aifoundry" 2>/dev/null || true
terraform import $VARS 'module.cognitive_services.azurerm_cognitive_deployment.gpt4o' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/aoai-aifoundry/deployments/gpt-4o" 2>/dev/null || true
terraform import $VARS 'module.cognitive_services.azurerm_cognitive_deployment.embedding' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/aoai-aifoundry/deployments/text-embedding-ada-002" 2>/dev/null || true
terraform import $VARS 'module.cognitive_services.azurerm_search_service.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Search/searchServices/srch-aifoundry-7kkykgt6" 2>/dev/null || true
terraform import $VARS 'module.cognitive_services.azurerm_private_dns_zone.search' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net" 2>/dev/null || true

# Monitoring
echo "8. Monitoring 리소스 import..."
terraform import $VARS 'module.monitoring.azurerm_log_analytics_workspace.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.OperationalInsights/workspaces/log-aifoundry" 2>/dev/null || true
terraform import $VARS 'module.monitoring.azurerm_application_insights.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Insights/components/appi-aifoundry" 2>/dev/null || true

# AI Foundry
echo "9. AI Foundry 리소스 import..."
terraform import $VARS 'module.ai_foundry.azapi_resource.hub' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.MachineLearningServices/workspaces/aihub-foundry" 2>/dev/null || true
terraform import $VARS 'module.ai_foundry.azapi_resource.project' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.MachineLearningServices/workspaces/aiproj-agents" 2>/dev/null || true
terraform import $VARS 'module.ai_foundry.azapi_resource.openai_connection' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.MachineLearningServices/workspaces/aihub-foundry/connections/aoai-connection" 2>/dev/null || true
terraform import $VARS 'module.ai_foundry.azapi_resource.search_connection[0]' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.MachineLearningServices/workspaces/aihub-foundry/connections/aisearch-connection" 2>/dev/null || true

# Jumpbox (Korea Central)
echo "10. Jumpbox (Korea Central) 리소스 import..."
terraform import $VARS 'module.jumpbox_krc.azurerm_virtual_network.jumpbox' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/vnet-jumpbox-krc" 2>/dev/null || true
terraform import $VARS 'module.jumpbox_krc.azurerm_network_security_group.jumpbox' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/networkSecurityGroups/nsg-jumpbox-krc" 2>/dev/null || true
terraform import $VARS 'module.jumpbox_krc.azurerm_public_ip.bastion' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/publicIPAddresses/pip-bastion-krc" 2>/dev/null || true
terraform import $VARS 'module.jumpbox_krc.azurerm_virtual_network_peering.main_to_jumpbox' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/vnet-aifoundry/virtualNetworkPeerings/peer-main-to-jumpbox" 2>/dev/null || true
terraform import $VARS 'module.jumpbox_krc.azurerm_virtual_network_peering.jumpbox_to_main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Network/virtualNetworks/vnet-jumpbox-krc/virtualNetworkPeerings/peer-jumpbox-to-main" 2>/dev/null || true

# APIM
echo "11. API Management import..."
terraform import $VARS 'module.apim.azurerm_api_management.main' "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.ApiManagement/service/apim-aifoundry-zj85lf" 2>/dev/null || true

echo "=== Import 완료 ==="
echo "terraform plan을 실행하여 상태를 확인하세요."
