# AI Foundry Agent Playground — 시스템 지침 (Instructions)

> 이 문서는 [Azure-Samples/azure-search-openai-demo](https://github.com/Azure-Samples/azure-search-openai-demo)의 RAG 패턴을 참고하여 작성되었습니다.
> Agent Playground의 **Instructions** 필드에 아래 프롬프트를 복사하여 사용하세요.

---

## 시스템 프롬프트

아래 내용을 Agent Playground의 **Instructions** 란에 붙여넣으세요.

```text
당신은 Zava(가상 기술 회사)의 사내 AI 어시스턴트입니다.
직원들이 사내 문서(복리후생, 직무, 사내 규정 등)에 대해 질문하면, 연결된 Azure AI Search 인덱스에서 관련 정보를 검색하여 정확하게 답변합니다.

## 핵심 규칙
1. **출처(Source) 기반 답변만 제공**: 검색된 문서에 포함된 사실만 사용하세요. 정보가 부족하면 "해당 정보를 찾을 수 없습니다"라고 답하세요.
2. **출처 인용 필수**: 답변에 사용한 정보의 출처를 반드시 표기하세요.
   - 형식: [파일명] (예: [Benefit_Options.pdf], [PerksPlus.pdf])
   - 여러 출처는 개별 표기: [Benefit_Options.pdf][PerksPlus.pdf]
3. **간결한 답변**: 핵심 내용을 간결하게 전달하세요.
4. **질문 언어에 맞춰 응답**: 한국어 질문에는 한국어로, 영어 질문에는 영어로 답변하세요.
5. **명확하지 않으면 되물어보기**: 질문이 모호하면 구체적인 확인 질문을 하세요.

## 후속 질문 생성
답변 끝에 사용자가 이어서 물어볼 만한 후속 질문 3개를 제안하세요.

## 답변 예시

**질문**: "처방전 약에 대한 보장은 어떻게 되나요?"

**답변**: Northwind Health Plus 플랜에서는 처방전 약에 대해 일반 의약품(generic) 기준 $10, 브랜드 의약품 $25의 본인부담금(copay)이 적용됩니다. 90일분 처방은 우편 주문 약국을 통해 할인된 가격으로 제공됩니다. [Northwind_Health_Plus_Benefits_Details.pdf]

Standard 플랜에서는 본인부담금이 일반 의약품 $15, 브랜드 의약품 $35입니다. [Northwind_Standard_Benefits_Details.pdf]

자세한 보장 옵션 비교는 복리후생 안내서를 참고하세요. [Benefit_Options.pdf]

**후속 질문 제안**:
- 처방전 약에 대한 보장 제외 항목이 있나요?
- 어떤 약국에서 주문할 수 있나요?
- 비처방 약품(OTC)에 대한 한도는 얼마인가요?
```

---

## 업로드된 샘플 데이터 안내

Storage Account `st93dfd463`의 `sample-data` 컨테이너에 업로드된 파일 목록입니다.

### 주요 PDF 문서

| 파일명 | 내용 | 주요 질문 예시 |
|--------|------|---------------|
| [Benefit_Options.pdf](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/data/Benefit_Options.pdf) | Northwind Health Plus / Standard 플랜 비교, 보험 옵션 개요 | "두 보험 플랜의 차이점은?", "가족 보험 옵션은?" |
| [Northwind_Health_Plus_Benefits_Details.pdf](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/data/Northwind_Health_Plus_Benefits_Details.pdf) | Northwind Health Plus 플랜 상세 (의료, 치과, 안과, 처방전) | "Health Plus 플랜의 처방전 본인부담금은?", "응급실 보장 범위는?" |
| [Northwind_Standard_Benefits_Details.pdf](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/data/Northwind_Standard_Benefits_Details.pdf) | Northwind Standard 플랜 상세 (기본 의료 보장) | "Standard 플랜의 연간 공제액은?", "외래 진료 보장은?" |
| [PerksPlus.pdf](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/data/PerksPlus.pdf) | PerksPlus 웰니스 프로그램 (헬스장, 건강 활동 지원금) | "PerksPlus로 어떤 활동을 지원받을 수 있나요?", "연간 지원 한도는?" |
| [employee_handbook.pdf](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/data/employee_handbook.pdf) | 사내 규정, 근무 정책, 행동 강령, 휴가 정책 | "재택근무 정책은?", "휴가 일수는 얼마인가요?" |
| [role_library.pdf](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/data/role_library.pdf) | 직무 목록 및 역할 설명 (엔지니어링, 마케팅, HR 등) | "시니어 엔지니어의 역할은?", "마케팅 팀 직무 목록은?" |

### 기타 파일

| 파일명 | 내용 |
|--------|------|
| [Zava_Company_Overview.md](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/data/Zava_Company_Overview.md) | Zava 회사 소개, 핵심 가치, 휴가 혜택, 직원 인정 프로그램 |
| [Json_Examples/](https://github.com/Azure-Samples/azure-search-openai-demo/tree/main/data/Json_Examples) | JSON 형식 데이터 파싱 예제 (구조화된 데이터 검색 테스트용) |

> **참고**: 이 PDF 문서들은 AI로 생성된 가상의 콘텐츠입니다. 실제 회사나 보험 상품과 무관합니다.

---

## Agent Playground 설정 방법

### 1. Agent 생성
1. [AI Foundry 포털](https://ai.azure.com)에서 프로젝트 접속
2. **Build** → **Agents** → **+ New Agent**
3. Model: `gpt-4o` 선택
4. Instructions에 위 시스템 프롬프트 붙여넣기

### 2. Knowledge (Azure AI Search 연결)
1. Agent 설정 화면에서 **Knowledge** 섹션 확장
2. **+ Add** → **Azure AI Search index** 선택
3. Connection: `srch-93dfd463` 선택
4. 인덱스 생성:
   - Index name: `sample-data-index`
   - Storage account: `st93dfd463`
   - Container: `sample-data`
   - Embedding model: `text-embedding-3-large`
5. **Create index** 클릭

> ⏱️ **인덱스 생성 소요 시간**: 예제 PDF 데이터(6개 PDF, 약 3.4MB) 기준으로 인덱스 생성에 **약 13분**이 소요됩니다. 진행 중 화면을 닫지 말고 완료될 때까지 대기하세요.

### 3. 테스트 질문 예시

| 카테고리 | 질문 |
|----------|------|
| 보험 비교 | "Northwind Health Plus와 Standard 플랜의 주요 차이점을 비교해줘" |
| 처방전 | "처방전 약에 대한 보장은 어떻게 되나요?" |
| 웰니스 | "PerksPlus 프로그램에서 지원하는 활동 목록은?" |
| 직무 | "소프트웨어 엔지니어의 역할과 책임을 알려줘" |
| 휴가 | "Zava의 휴가 정책은 어떻게 되나요?" |
| 사내 규정 | "재택근무 관련 정책이 있나요?" |
| 멀티턴 | "Health Plus 플랜에서 치과 보장은?" → "Standard 플랜과 비교하면?" |

---

## 참고 자료

- [azure-search-openai-demo (GitHub)](https://github.com/Azure-Samples/azure-search-openai-demo) — RAG 패턴 참조 프로젝트
- [ChatReadRetrieveRead 패턴](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/app/backend/approaches/chatreadretrieveread.py) — 질문→검색→답변 3단계 접근 방식
- [시스템 프롬프트 원본](https://github.com/Azure-Samples/azure-search-openai-demo/blob/main/app/backend/approaches/prompts/chat_answer.system.jinja2) — Jinja2 기반 프롬프트 템플릿
