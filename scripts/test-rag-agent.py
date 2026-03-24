#!/usr/bin/env python3
"""
Azure AI Foundry Agent 생성 및 RAG 테스트
- AI Search 벡터 인덱스 연동
- azure-search-openai-demo 시스템 프롬프트 적용
- 원본 문서 소스 링크 포함 응답
"""
import json
import sys
import argparse
import subprocess

from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from openai import AzureOpenAI

# azure-search-openai-demo 기반 시스템 프롬프트 (소스 인용 포함)
SYSTEM_PROMPT = """Assistant helps the company employees with their questions about internal documents. Be brief in your answers.
Answer ONLY with the facts listed in the list of sources below. If there isn't enough information below, say you don't know. Do not generate answers that don't use the sources below.
If asking a clarifying question to the user would help, ask the question.
If the question is not in English, answer in the language used in the question.
Each source has a name followed by colon and the actual information, always include the source name for each fact you use in the response. Use square brackets to reference the source, for example [info1.txt]. Don't combine sources, list each source separately, for example [info1.txt][info2.pdf].

IMPORTANT: For each source reference, also provide a clickable link in the format:
📎 [source_filename](https://{storage_account}.blob.core.windows.net/rag-documents/source_filename)

At the end of your response, list all referenced sources under a "Sources" section with direct links.

Generate 3 very brief follow-up questions that the user would likely ask next.
Enclose the follow-up questions in double angle brackets. Example:
<<Are there exclusions for prescriptions?>>
<<Which pharmacies can be ordered from?>>
<<What is the limit for over-the-counter medication?>>
Do not repeat questions that have already been asked.
Make sure the last question ends with ">>"."""


def parse_args():
    parser = argparse.ArgumentParser(description="Agent 생성 및 RAG 테스트")
    parser.add_argument("--resource-group", "-g", required=True)
    parser.add_argument("--index-name", default="rag-index")
    parser.add_argument("--query", "-q", default="What does the PerksPlus program cover? Is there a spending limit?")
    return parser.parse_args()


def get_resource_names(rg: str) -> dict:
    result = subprocess.run(
        ["az", "resource", "list", "-g", rg, "--query",
         "[].{name:name, type:type}", "-o", "json"],
        capture_output=True, text=True
    )
    resources = json.loads(result.stdout)
    names = {}
    for r in resources:
        t = r["type"]
        n = r["name"]
        if "CognitiveServices/accounts" in t and "/" not in n:
            names["cognitive"] = n
        elif "Storage/storageAccounts" in t:
            names["storage"] = n
        elif "Search/searchServices" in t:
            names["search"] = n
    return names


def search_documents(credential, search_name: str, cognitive_name: str,
                     index_name: str, query: str, top_k: int = 5) -> list[dict]:
    """벡터 + 시맨틱 하이브리드 검색"""
    search_endpoint = f"https://{search_name}.search.windows.net"
    search_client = SearchClient(search_endpoint, index_name, credential)

    token = credential.get_token("https://cognitiveservices.azure.com/.default")
    oai_client = AzureOpenAI(
        azure_endpoint=f"https://{cognitive_name}.openai.azure.com",
        api_version="2024-10-21",
        azure_ad_token=token.token,
    )

    # 쿼리 임베딩
    emb_response = oai_client.embeddings.create(input=query, model="text-embedding-3-large")
    query_vector = emb_response.data[0].embedding

    vector_query = VectorizedQuery(
        vector=query_vector, k_nearest_neighbors=top_k, fields="content_vector"
    )

    results = search_client.search(
        search_text=query,
        vector_queries=[vector_query],
        query_type="semantic",
        semantic_configuration_name="semantic-config",
        top=top_k,
    )

    sources = []
    for r in results:
        sources.append({
            "source": r.get("source", "unknown"),
            "content": r["content"],
            "score": r.get("@search.score", 0),
        })
    return sources


def run_agent_chat(credential, cognitive_name: str, storage_name: str,
                   query: str, sources: list[dict]):
    """GPT-4o로 RAG 응답 생성 (소스 링크 포함)"""
    token = credential.get_token("https://cognitiveservices.azure.com/.default")
    oai_client = AzureOpenAI(
        azure_endpoint=f"https://{cognitive_name}.openai.azure.com",
        api_version="2024-10-21",
        azure_ad_token=token.token,
    )

    # 소스 문서를 컨텍스트로 구성
    source_texts = []
    for s in sources:
        source_texts.append(f"{s['source']}: {s['content']}")
    context = "\n\n".join(source_texts)

    # 시스템 프롬프트에 storage account 이름 주입
    system = SYSTEM_PROMPT.replace("{storage_account}", storage_name)

    # 가용한 소스 목록
    citation_list = list(set(s["source"] for s in sources))
    system += f"\n\nPossible citations for current question: {' '.join(f'[{c}]' for c in citation_list)}"

    response = oai_client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": f"Sources:\n{context}\n\nQuestion: {query}"},
        ],
        temperature=0.3,
        max_tokens=1000,
    )

    return response.choices[0].message.content


def main():
    args = parse_args()
    credential = DefaultAzureCredential()

    print("=" * 70)
    print("  AI Foundry Agent - RAG 테스트 (원본 문서 링크 포함)")
    print("=" * 70)

    # 리소스 감지
    print("\n📡 리소스 감지 중...")
    names = get_resource_names(args.resource_group)
    print(f"  Cognitive: {names['cognitive']}")
    print(f"  Storage:   {names['storage']}")
    print(f"  Search:    {names['search']}")

    # 벡터 검색
    print(f"\n🔍 검색 중: \"{args.query}\"")
    sources = search_documents(
        credential, names["search"], names["cognitive"],
        args.index_name, args.query
    )
    print(f"  {len(sources)}개 소스 문서 검색 완료")
    for i, s in enumerate(sources):
        print(f"    [{i+1}] {s['source']} (score: {s['score']:.4f})")

    # Agent 응답 생성
    print("\n🤖 Agent 응답 생성 중...")
    answer = run_agent_chat(
        credential, names["cognitive"], names["storage"],
        args.query, sources
    )

    print("\n" + "─" * 70)
    print(f"  💬 질문: {args.query}")
    print("─" * 70)
    print(f"\n{answer}")
    print("\n" + "─" * 70)

    # 원본 문서 링크 표시
    storage_url = f"https://{names['storage']}.blob.core.windows.net/rag-documents"
    print("\n📎 원본 문서 다운로드 링크:")
    seen = set()
    for s in sources:
        if s["source"] not in seen:
            seen.add(s["source"])
            print(f"  • {s['source']}: {storage_url}/{s['source']}")

    print("\n✅ Agent RAG 테스트 완료!")


if __name__ == "__main__":
    main()
