#!/usr/bin/env python3
"""
RAG 인덱스 구성 스크립트
- PDF 문서를 텍스트로 변환 + 청킹
- Azure AI Search에 벡터 인덱스 생성
- text-embedding-3-large로 임베딩 생성 후 인덱싱
- GPT-4o로 RAG 검색 테스트
"""
import os
import sys
import json
import argparse
from pathlib import Path

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SearchField,
    SearchFieldDataType,
    SimpleField,
    SearchableField,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
    SearchIndex,
    SemanticConfiguration,
    SemanticSearch,
    SemanticPrioritizedFields,
    SemanticField,
)
from openai import AzureOpenAI
from PyPDF2 import PdfReader


def parse_args():
    parser = argparse.ArgumentParser(description="RAG 인덱스 구성")
    parser.add_argument("--resource-group", "-g", required=True)
    parser.add_argument("--data-dir", default="/tmp/azure-search-openai-demo/data")
    parser.add_argument("--index-name", default="rag-index")
    parser.add_argument("--chunk-size", type=int, default=1000)
    parser.add_argument("--chunk-overlap", type=int, default=200)
    return parser.parse_args()


def get_resource_names(rg: str) -> dict:
    """리소스 그룹에서 리소스 이름을 자동 감지"""
    import subprocess
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


def extract_text_from_pdf(pdf_path: str) -> str:
    """PDF에서 텍스트 추출"""
    reader = PdfReader(pdf_path)
    text = ""
    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            text += page_text + "\n"
    return text


def chunk_text(text: str, chunk_size: int = 1000, overlap: int = 200) -> list[str]:
    """텍스트를 청킹"""
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end]
        if chunk.strip():
            chunks.append(chunk.strip())
        start = end - overlap
    return chunks


def upload_to_storage(credential, storage_name: str, data_dir: str):
    """문서를 Storage에 업로드"""
    blob_url = f"https://{storage_name}.blob.core.windows.net"
    blob_client = BlobServiceClient(blob_url, credential=credential)
    container_client = blob_client.get_container_client("rag-documents")

    uploaded = 0
    for f in Path(data_dir).glob("*.pdf"):
        blob = container_client.get_blob_client(f.name)
        with open(f, "rb") as data:
            blob.upload_blob(data, overwrite=True)
        uploaded += 1
        print(f"  ✅ {f.name} 업로드 완료")

    # MD 파일도
    for f in Path(data_dir).glob("*.md"):
        blob = container_client.get_blob_client(f.name)
        with open(f, "rb") as data:
            blob.upload_blob(data, overwrite=True)
        uploaded += 1
        print(f"  ✅ {f.name} 업로드 완료")

    print(f"  총 {uploaded}개 파일 업로드 완료")


def create_search_index(credential, search_name: str, index_name: str):
    """AI Search 벡터 인덱스 생성"""
    endpoint = f"https://{search_name}.search.windows.net"
    index_client = SearchIndexClient(endpoint, credential)

    fields = [
        SimpleField(name="id", type=SearchFieldDataType.String, key=True, filterable=True),
        SearchableField(name="content", type=SearchFieldDataType.String, analyzer_name="ko.microsoft"),
        SimpleField(name="source", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="chunk_id", type=SearchFieldDataType.Int32, filterable=True),
        SearchField(
            name="content_vector",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=3072,
            vector_search_profile_name="vector-profile",
        ),
    ]

    vector_search = VectorSearch(
        algorithms=[HnswAlgorithmConfiguration(name="hnsw-config")],
        profiles=[VectorSearchProfile(name="vector-profile", algorithm_configuration_name="hnsw-config")],
    )

    semantic_config = SemanticConfiguration(
        name="semantic-config",
        prioritized_fields=SemanticPrioritizedFields(
            content_fields=[SemanticField(field_name="content")]
        ),
    )
    semantic_search = SemanticSearch(configurations=[semantic_config])

    index = SearchIndex(
        name=index_name,
        fields=fields,
        vector_search=vector_search,
        semantic_search=semantic_search,
    )

    result = index_client.create_or_update_index(index)
    print(f"  ✅ 인덱스 '{result.name}' 생성 완료")


def index_documents(credential, search_name: str, cognitive_name: str,
                    index_name: str, data_dir: str, chunk_size: int, chunk_overlap: int):
    """문서를 청킹 → 임베딩 → 인덱싱"""
    search_endpoint = f"https://{search_name}.search.windows.net"
    search_client = SearchClient(search_endpoint, index_name, credential)

    # OpenAI 클라이언트 (임베딩용)
    token = credential.get_token("https://cognitiveservices.azure.com/.default")
    oai_client = AzureOpenAI(
        azure_endpoint=f"https://{cognitive_name}.openai.azure.com",
        api_version="2024-10-21",
        azure_ad_token=token.token,
    )

    documents = []
    doc_id = 0

    # PDF 처리
    for pdf_path in Path(data_dir).glob("*.pdf"):
        print(f"  📄 처리 중: {pdf_path.name}")
        text = extract_text_from_pdf(str(pdf_path))
        chunks = chunk_text(text, chunk_size, chunk_overlap)

        for i, chunk in enumerate(chunks):
            # 임베딩 생성
            response = oai_client.embeddings.create(
                input=chunk,
                model="text-embedding-3-large"
            )
            embedding = response.data[0].embedding

            documents.append({
                "id": str(doc_id),
                "content": chunk,
                "source": pdf_path.name,
                "chunk_id": i,
                "content_vector": embedding,
            })
            doc_id += 1

    # MD 처리
    for md_path in Path(data_dir).glob("*.md"):
        print(f"  📄 처리 중: {md_path.name}")
        text = md_path.read_text(encoding="utf-8")
        chunks = chunk_text(text, chunk_size, chunk_overlap)

        for i, chunk in enumerate(chunks):
            response = oai_client.embeddings.create(
                input=chunk,
                model="text-embedding-3-large"
            )
            embedding = response.data[0].embedding

            documents.append({
                "id": str(doc_id),
                "content": chunk,
                "source": md_path.name,
                "chunk_id": i,
                "content_vector": embedding,
            })
            doc_id += 1

    # 배치 업로드
    batch_size = 100
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i + batch_size]
        result = search_client.upload_documents(batch)
        succeeded = sum(1 for r in result if r.succeeded)
        print(f"  ✅ 배치 {i // batch_size + 1}: {succeeded}/{len(batch)} 인덱싱 완료")

    print(f"  총 {doc_id}개 청크 인덱싱 완료")


def test_rag(credential, search_name: str, cognitive_name: str, index_name: str):
    """RAG 검색 + GPT 응답 테스트"""
    from azure.search.documents.models import VectorizedQuery

    search_endpoint = f"https://{search_name}.search.windows.net"
    search_client = SearchClient(search_endpoint, index_name, credential)

    token = credential.get_token("https://cognitiveservices.azure.com/.default")
    oai_client = AzureOpenAI(
        azure_endpoint=f"https://{cognitive_name}.openai.azure.com",
        api_version="2024-10-21",
        azure_ad_token=token.token,
    )

    query = "What are the employee benefits for dental care?"
    print(f"\n  🔍 테스트 질문: {query}")

    # 쿼리 임베딩
    query_response = oai_client.embeddings.create(input=query, model="text-embedding-3-large")
    query_vector = query_response.data[0].embedding

    vector_query = VectorizedQuery(vector=query_vector, k_nearest_neighbors=3, fields="content_vector")

    results = search_client.search(
        search_text=query,
        vector_queries=[vector_query],
        query_type="semantic",
        semantic_configuration_name="semantic-config",
        top=3,
    )

    context_parts = []
    print("\n  📋 검색 결과:")
    for i, result in enumerate(results):
        score = result.get("@search.score", 0)
        source = result.get("source", "unknown")
        content = result["content"][:200]
        print(f"    [{i+1}] {source} (score: {score:.4f})")
        print(f"        {content}...")
        context_parts.append(result["content"])

    # GPT로 응답 생성
    context = "\n---\n".join(context_parts)
    response = oai_client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "You are a helpful assistant. Answer based on the provided context only."},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {query}"},
        ],
        temperature=0,
        max_tokens=500,
    )

    answer = response.choices[0].message.content
    print(f"\n  🤖 GPT-4o 응답:\n{answer}")
    print("\n  ✅ RAG 테스트 완료!")


def main():
    args = parse_args()
    credential = DefaultAzureCredential()

    print("=" * 60)
    print(" RAG 인덱스 구성 시작")
    print("=" * 60)

    # 리소스 이름 감지
    print("\n[1/5] 리소스 이름 감지...")
    names = get_resource_names(args.resource_group)
    print(f"  Cognitive: {names.get('cognitive')}")
    print(f"  Storage:   {names.get('storage')}")
    print(f"  Search:    {names.get('search')}")

    if not all(k in names for k in ("cognitive", "storage", "search")):
        print("❌ 필요한 리소스를 찾을 수 없습니다.")
        sys.exit(1)

    # Storage에 문서 업로드
    print("\n[2/5] Storage에 문서 업로드...")
    upload_to_storage(credential, names["storage"], args.data_dir)

    # AI Search 인덱스 생성
    print("\n[3/5] AI Search 벡터 인덱스 생성...")
    create_search_index(credential, names["search"], args.index_name)

    # 문서 인덱싱
    print("\n[4/5] 문서 청킹 → 임베딩 → 인덱싱...")
    index_documents(
        credential, names["search"], names["cognitive"],
        args.index_name, args.data_dir, args.chunk_size, args.chunk_overlap
    )

    # RAG 테스트
    print("\n[5/5] RAG 검색 + GPT 응답 테스트...")
    test_rag(credential, names["search"], names["cognitive"], args.index_name)

    print("\n" + "=" * 60)
    print(" RAG 구성 완료!")
    print("=" * 60)


if __name__ == "__main__":
    main()
