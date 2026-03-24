#!/usr/bin/env python3
"""Classic Hub RAG 인덱스 구성 - text-embedding-ada-002 + 한국어 지원"""
from pathlib import Path
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from openai import AzureOpenAI
from PyPDF2 import PdfReader

STORAGE = "stcn4v5czon"
SEARCH = "srch-mmf5sjfd"
OAI = "oai-mmf5sjfd"
DATA_DIR = "/tmp/azure-search-openai-demo/data"
INDEX = "rag-index"
EMBED_MODEL = "text-embedding-ada-002"

cred = DefaultAzureCredential()

# [1] Storage 업로드
print("[1/3] Storage 업로드...")
blob_client = BlobServiceClient(f"https://{STORAGE}.blob.core.windows.net", credential=cred)
container = blob_client.get_container_client("rag-documents")
for f in list(Path(DATA_DIR).glob("*.pdf")) + list(Path(DATA_DIR).glob("*.md")):
    blob = container.get_blob_client(f.name)
    with open(f, "rb") as data:
        blob.upload_blob(data, overwrite=True)
    print(f"  OK: {f.name}")

# [2] 임베딩 + 인덱싱
print("[2/3] 청킹 + 임베딩 + 인덱싱...")
token = cred.get_token("https://cognitiveservices.azure.com/.default")
oai = AzureOpenAI(
    azure_endpoint=f"https://{OAI}.openai.azure.com",
    api_version="2024-10-21",
    azure_ad_token=token.token,
)
search = SearchClient(f"https://{SEARCH}.search.windows.net", INDEX, cred)

docs = []
doc_id = 0

for pdf in sorted(Path(DATA_DIR).glob("*.pdf")):
    print(f"  {pdf.name}")
    reader = PdfReader(str(pdf))
    text = "".join(p.extract_text() or "" for p in reader.pages)
    for i in range(0, len(text), 800):
        chunk = text[i:i+1000].strip()
        if not chunk:
            continue
        # 토큰 갱신 (대용량 PDF 처리 시 만료 방지)
        token = cred.get_token("https://cognitiveservices.azure.com/.default")
        oai = AzureOpenAI(
            azure_endpoint=f"https://{OAI}.openai.azure.com",
            api_version="2024-10-21",
            azure_ad_token=token.token,
        )
        emb = oai.embeddings.create(input=chunk, model=EMBED_MODEL).data[0].embedding
        docs.append({"id": str(doc_id), "content": chunk, "source": pdf.name, "chunk_id": i // 800, "content_vector": emb})
        doc_id += 1

for md in sorted(Path(DATA_DIR).glob("*.md")):
    print(f"  {md.name}")
    text = md.read_text(encoding="utf-8")
    for i in range(0, len(text), 800):
        chunk = text[i:i+1000].strip()
        if not chunk:
            continue
        token = cred.get_token("https://cognitiveservices.azure.com/.default")
        oai = AzureOpenAI(
            azure_endpoint=f"https://{OAI}.openai.azure.com",
            api_version="2024-10-21",
            azure_ad_token=token.token,
        )
        emb = oai.embeddings.create(input=chunk, model=EMBED_MODEL).data[0].embedding
        docs.append({"id": str(doc_id), "content": chunk, "source": md.name, "chunk_id": i // 800, "content_vector": emb})
        doc_id += 1

for i in range(0, len(docs), 100):
    batch = docs[i:i+100]
    result = search.upload_documents(batch)
    ok = sum(1 for r in result if r.succeeded)
    print(f"  batch {i//100+1}: {ok}/{len(batch)}")
print(f"  total: {doc_id} chunks")

# [3] 한국어 검색 테스트
print("[3/3] 한국어 검색 테스트...")
token2 = cred.get_token("https://cognitiveservices.azure.com/.default")
oai2 = AzureOpenAI(azure_endpoint=f"https://{OAI}.openai.azure.com", api_version="2024-10-21", azure_ad_token=token2.token)

q = "치과 혜택은 어떤 것들이 있나요?"
qe = oai2.embeddings.create(input=q, model=EMBED_MODEL).data[0].embedding
vq = VectorizedQuery(vector=qe, k_nearest_neighbors=3, fields="content_vector")
results = search.search(search_text=q, vector_queries=[vq], query_type="semantic", semantic_configuration_name="semantic-config", top=3)
print(f"  Q: {q}")
for i, r in enumerate(results):
    print(f"  [{i+1}] {r['source']} (score={r.get('@search.score',0):.4f}): {r['content'][:100]}...")

# GPT-4o RAG 응답
print("\n  GPT-4o RAG 응답:")
context = "\n---\n".join(r["content"] for r in search.search(search_text=q, vector_queries=[vq], query_type="semantic", semantic_configuration_name="semantic-config", top=3))
resp = oai2.chat.completions.create(model="gpt-4o", messages=[
    {"role": "system", "content": "내부 문서 기반으로 답변. 소스 파일명을 [brackets]로 표시."},
    {"role": "user", "content": f"Sources:\n{context}\n\nQuestion: {q}"},
], temperature=0, max_tokens=500)
print(f"  {resp.choices[0].message.content}")
print("\nDONE!")
