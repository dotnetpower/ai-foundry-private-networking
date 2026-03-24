#!/usr/bin/env python3
"""
AI Foundry Private Networking Infrastructure Diagram
현재 배포된 Azure 인프라를 시각화합니다.

업데이트: 2026-01-28
- Azure Bastion 추가
- APIM 개발자 포털 추가
- AI Foundry Hub/Project (azapi) 반영
- 가로 레이아웃 최적화
- 리소스 상세 정보 추가
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.azure.compute import VM, ContainerRegistries
from diagrams.azure.aimachinelearning import AIStudio, CognitiveServices, CognitiveSearch
from diagrams.azure.ml import AzureOpenAI
from diagrams.azure.network import (
    VirtualNetworks, 
    Subnets, 
    PrivateEndpoint, 
    NetworkSecurityGroupsClassic as NetworkSecurityGroups,
    VirtualNetworkGateways,
)
from diagrams.azure.storage import StorageAccounts
from diagrams.azure.security import KeyVaults
from diagrams.azure.analytics import LogAnalyticsWorkspaces
from diagrams.azure.devops import ApplicationInsights
from diagrams.azure.identity import ManagedIdentities
from diagrams.azure.integration import APIManagement
from diagrams.onprem.client import Users

# 다이어그램 설정 - 가로 레이아웃
graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "spline",
    "nodesep": "0.6",
    "ranksep": "1.2",
}

node_attr = {
    "fontsize": "10",
    "fontname": "Sans-Serif",
}

edge_attr = {
    "fontsize": "9",
}


def main():
    """AI Foundry 인프라 다이어그램을 생성합니다."""
    with Diagram(
        "AI Foundry Private Networking Architecture",
        filename="ai_foundry_infrastructure",
        direction="LR",
        graph_attr=graph_attr,
        node_attr=node_attr,
        edge_attr=edge_attr,
        show=False,
        outformat="png"
    ):
        
        # ========== 1. 사용자 ==========
        with Cluster("사내 네트워크\nOn-Premises"):
            users = Users("개발자\n관리자")
        
        # ========== 2. Korea Central (Bastion + Jumpbox) ==========
        with Cluster("Korea Central\nvnet-jumpbox-krc (10.1.0.0/16)"):
            bastion = VirtualNetworkGateways("Azure Bastion\nbastion-jumpbox\nStandard SKU")
            
            with Cluster("snet-jumpbox (10.1.1.0/24)"):
                win_vm = VM("vm-jumpbox-win\nWindows 11 Pro\nD4s_v3 (4vCPU/16GB)\nPython 3.12")
                linux_vm = VM("vm-jumpbox-linux\nUbuntu 22.04 LTS\nD4s_v3 (4vCPU/16GB)\nPython 3.12 + uv")
        
        # ========== 3. VNet Peering ==========
        peering = VirtualNetworks("VNet Peering\nkrc ↔ eus")
        
        # ========== 4. East US (Main Infrastructure) ==========
        with Cluster("East US\nvnet-ai-foundry (10.0.0.0/16)"):
            
            # APIM
            with Cluster("snet-apim (10.0.3.0/24)"):
                apim = APIManagement("apim-ai-foundry\nDeveloper SKU\n개발자 포털 활성화\n3-tier 권한 체계")
            
            # AI Foundry
            with Cluster("AI Foundry (azapi)"):
                ai_hub = AIStudio("aihub-foundry\nkind=Hub\nManaged VNet")
                ai_project = AIStudio("aiproj-agents\nkind=Project\nAgent 개발용")
            
            # AI Services
            with Cluster("Azure AI Services"):
                openai = AzureOpenAI("oai-foundry\nGPT-4o (8K TPM)\nada-002 (120K TPM)")
                ai_search = CognitiveSearch("srch-foundry\nBasic SKU\nRAG 패턴")
            
            # Dependencies
            with Cluster("의존 서비스 (Private Endpoint)"):
                storage = StorageAccounts("stfoundry\nStandard LRS\nBlob + File")
                acr = ContainerRegistries("acrfoundry\nBasic SKU")
                kv = KeyVaults("kv-foundry\nStandard SKU\nRBAC 인증")
                appins = ApplicationInsights("appi-foundry\nLog Analytics 연동")
        
        # ========== 연결 ==========
        # 사용자 → Bastion (Azure Portal)
        users >> Edge(color="blue", label="Azure Portal\nBastion 연결") >> bastion
        
        # Bastion → Jumpbox (RDP/SSH Tunnel)
        bastion >> Edge(color="green", label="RDP") >> win_vm
        bastion >> Edge(color="green", label="SSH") >> linux_vm
        
        # Jumpbox → Peering (Private Access)
        win_vm >> Edge(color="darkgreen", style="bold", label="Private") >> peering
        linux_vm >> Edge(color="darkgreen", style="bold") >> peering
        
        # Peering → Services
        peering >> Edge(color="orange", label="API 호출") >> apim
        peering >> Edge(color="purple", label="Studio") >> ai_hub
        
        # APIM → OpenAI (Rate Limited)
        apim >> Edge(color="red", label="100-500/min") >> openai
        
        # AI Foundry 관계
        ai_hub >> Edge(label="Parent") >> ai_project
        ai_hub >> Edge(color="darkblue") >> openai
        ai_hub >> Edge(color="darkblue") >> ai_search
        
        # Dependencies (dotted lines)
        ai_hub >> Edge(style="dotted", color="gray") >> storage
        ai_hub >> Edge(style="dotted", color="gray") >> acr
        ai_hub >> Edge(style="dotted", color="gray") >> kv
        ai_hub >> Edge(style="dotted", color="gray") >> appins

    print("✅ 다이어그램 생성 완료: ai_foundry_infrastructure.png")
    print("")
    print("📐 레이아웃: 가로 (Left to Right)")
    print("")
    print("🔄 데이터 흐름:")
    print("   사내 네트워크 → Azure Bastion → Jumpbox VMs → VNet Peering → East US")
    print("")
    print("   개발자: → APIM 개발자 포털 → Azure OpenAI API (Rate Limited)")
    print("   관리자: → AI Foundry Studio → Hub/Project 관리")
    print("")
    print("📋 주요 리소스:")
    print("   - AI Hub: aihub-foundry (Managed VNet)")
    print("   - AI Project: aiproj-agents (Agent 개발)")
    print("   - OpenAI: GPT-4o (8K TPM), ada-002 (120K TPM)")
    print("   - APIM: 3-tier 권한 (Developer/Production/Unlimited)")


if __name__ == "__main__":
    main()
