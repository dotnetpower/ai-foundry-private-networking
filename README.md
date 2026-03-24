# AI Foundry Private Networking — Bicep IaC

Azure AI Foundry의 **E2E Private Networking** 환경을 Bicep으로 구성하는 프로젝트입니다.
Classic(Hub) 기반 Managed VNet부터 New Foundry 기반 직접 VNet/PE까지, 단계별 마이그레이션 경로를 제공합니다.

> **단계별 구성 파이프라인**: [docs/phased-migration-pipeline.md](docs/phased-migration-pipeline.md) 참조

## 배포 구성

| 구성 | 폴더 | 네트워크 격리 | 상태 |
|------|------|:----------:|------|
| **Classic + Managed VNet** | `infra-foundry-classic/` | ✅ E2E Private | 구현 예정 |
| **New Foundry Standard** | `infra-foundry-new/standard/` | ✅ E2E Private | 구현 완료(New Foundry 불안정) |
| **New Foundry Hosted Agent** | `infra-foundry-new/hosted/` | ❌ Public Only | 구현 완료 |

## 프로젝트 구조

```
infra-foundry-classic/              # Phase 1: Classic Hub + Managed VNet
infra-foundry-new/
├── standard/                       # Phase 2: New Foundry + 직접 VNet/PE
└── hosted/                         # Phase 3: New Foundry + Hosted Agent (Public)
scripts/                            # 배포/검증 스크립트
docs/                               # 가이드 문서
```

각 배포 구성의 상세 가이드는 해당 폴더의 README.md를 참조하세요.

## 사전 요구사항

- [Azure CLI](https://docs.microsoft.com/cli/azure/) 최신 버전
- Azure 구독 (Owner 또는 Contributor + Role Based Access Administrator)

## 참고 자료

- [Azure AI Foundry Network Isolation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/network-isolation)
- [Set up private networking for Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)
- [What are hosted agents?](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/hosted-agents)

- https://learn.microsoft.com/en-us/collections/075ysqe443dd4p?WT.mc_id=academic-105485-koreyst

## 라이선스

MIT License - [LICENSE](LICENSE) 참조
