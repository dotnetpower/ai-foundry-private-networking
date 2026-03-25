"""
Azure Search OpenAI Demo — Classic Hub 맞춤 웹앱
azure-search-openai-demo 패턴 기반, infra-foundry-classic/basic 리소스 연동
"""
import json
import logging
import os

from quart import Quart, request, jsonify, render_template, send_from_directory
from azure.identity.aio import DefaultAzureCredential
from azure.search.documents.aio import SearchClient
from azure.search.documents.models import VectorizedQuery
from openai import AsyncAzureOpenAI

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("webapp")

app = Quart(__name__, static_folder="static", template_folder="templates")

# ---------------------------------------------------------------------------
# 설정 — .env 또는 환경 변수에서 로드
# ---------------------------------------------------------------------------
AZURE_OPENAI_ENDPOINT = os.environ["AZURE_OPENAI_ENDPOINT"]
AZURE_OPENAI_CHAT_DEPLOYMENT = os.environ.get("AZURE_OPENAI_CHAT_DEPLOYMENT", "gpt-4o")
AZURE_OPENAI_EMB_DEPLOYMENT = os.environ.get("AZURE_OPENAI_EMB_DEPLOYMENT", "text-embedding-ada-002")
AZURE_SEARCH_ENDPOINT = os.environ["AZURE_SEARCH_ENDPOINT"]
AZURE_SEARCH_INDEX = os.environ.get("AZURE_SEARCH_INDEX", "rag-index")
AZURE_STORAGE_ACCOUNT = os.environ.get("AZURE_STORAGE_ACCOUNT", "")

# azure-search-openai-demo 시스템 프롬프트
SYSTEM_PROMPT = """Assistant helps the company employees with their questions about internal documents.
Be brief in your answers.
Answer ONLY with the facts listed in the list of sources below.
If there isn't enough information below, say you don't know.
Do not generate answers that don't use the sources below.
If asking a clarifying question to the user would help, ask the question.
If the question is not in English, answer in the language used in the question.

Each source has a name followed by colon and the actual information.
Always include the source name for each fact you use in the response.
Use square brackets to reference the source, for example [info1.txt].
Don't combine sources, list each source separately, for example [info1.txt][info2.pdf].

Generate 3 very brief follow-up questions that the user would likely ask next.
Enclose the follow-up questions in double angle brackets. Example:
<<Are there exclusions for prescriptions?>>
<<Which pharmacies can be ordered from?>>
<<What is the limit for over-the-counter medication?>>
Do not repeat questions that have already been asked.
Make sure the last question ends with ">>"."""

# ---------------------------------------------------------------------------
# 전역 리소스 (앱 수명 주기)
# ---------------------------------------------------------------------------
credential: DefaultAzureCredential | None = None
openai_client: AsyncAzureOpenAI | None = None


@app.before_serving
async def startup():
    global credential, openai_client
    credential = DefaultAzureCredential()
    token = await credential.get_token("https://cognitiveservices.azure.com/.default")
    openai_client = AsyncAzureOpenAI(
        azure_endpoint=AZURE_OPENAI_ENDPOINT,
        azure_ad_token=token.token,
        api_version="2024-10-21",
    )
    logger.info("OpenAI client initialized — endpoint=%s", AZURE_OPENAI_ENDPOINT)


@app.after_serving
async def shutdown():
    if credential:
        await credential.close()


# ---------------------------------------------------------------------------
# 헬퍼
# ---------------------------------------------------------------------------
async def _refresh_openai():
    """토큰 갱신 후 새 클라이언트 반환"""
    global openai_client
    token = await credential.get_token("https://cognitiveservices.azure.com/.default")
    openai_client = AsyncAzureOpenAI(
        azure_endpoint=AZURE_OPENAI_ENDPOINT,
        azure_ad_token=token.token,
        api_version="2024-10-21",
    )
    return openai_client


async def _search(query: str, top_k: int = 5) -> list[dict]:
    """AI Search 벡터 + 시맨틱 하이브리드 검색"""
    client = await _refresh_openai()

    emb = await client.embeddings.create(input=query, model=AZURE_OPENAI_EMB_DEPLOYMENT)
    query_vector = emb.data[0].embedding

    vector_query = VectorizedQuery(
        vector=query_vector, k_nearest_neighbors=top_k, fields="content_vector"
    )

    async with SearchClient(
        AZURE_SEARCH_ENDPOINT, AZURE_SEARCH_INDEX, credential
    ) as search:
        results = await search.search(
            search_text=query,
            vector_queries=[vector_query],
            query_type="semantic",
            semantic_configuration_name="semantic-config",
            top=top_k,
        )
        docs = []
        async for r in results:
            docs.append({
                "source": r.get("source", "unknown"),
                "content": r["content"],
                "score": r.get("@search.score", 0),
            })
    return docs


# ---------------------------------------------------------------------------
# 페이지 라우트
# ---------------------------------------------------------------------------
@app.route("/")
async def index():
    return await render_template("index.html")


@app.route("/favicon.ico")
async def favicon():
    return await send_from_directory(app.static_folder, "favicon.ico")


# ---------------------------------------------------------------------------
# API 엔드포인트
# ---------------------------------------------------------------------------
@app.route("/chat", methods=["POST"])
async def chat():
    """채팅 API — RAG 기반 응답 (azure-search-openai-demo /chat 패턴)"""
    body = await request.get_json()
    messages = body.get("messages", [])
    if not messages:
        return jsonify({"error": "messages required"}), 400

    user_query = messages[-1].get("content", "")
    top_k = body.get("top", 5)
    temperature = body.get("temperature", 0.3)

    # 1. 검색
    try:
        sources = await _search(user_query, top_k)
    except Exception as e:
        logger.exception("Search failed")
        return jsonify({"error": f"Search failed: {e}"}), 500

    # 2. 소스 컨텍스트 구성
    source_texts = [f"{s['source']}: {s['content']}" for s in sources]
    context = "\n\n".join(source_texts)

    # 3. GPT-4o 호출
    client = await _refresh_openai()
    chat_messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
    ]
    # 이전 대화 히스토리 추가
    for m in messages[:-1]:
        chat_messages.append({"role": m["role"], "content": m["content"]})
    chat_messages.append({
        "role": "user",
        "content": f"Sources:\n{context}\n\nQuestion: {user_query}",
    })

    try:
        completion = await client.chat.completions.create(
            model=AZURE_OPENAI_CHAT_DEPLOYMENT,
            messages=chat_messages,
            temperature=temperature,
            max_tokens=1024,
        )
    except Exception as e:
        logger.exception("OpenAI call failed")
        return jsonify({"error": f"OpenAI call failed: {e}"}), 500

    answer = completion.choices[0].message.content

    # 4. 응답
    return jsonify({
        "answer": answer,
        "sources": [
            {
                "source": s["source"],
                "score": round(s["score"], 4),
                "content": s["content"][:200],
            }
            for s in sources
        ],
    })


@app.route("/ask", methods=["POST"])
async def ask():
    """단일 질문 API — 대화 기록 없이 1-turn RAG"""
    body = await request.get_json()
    question = body.get("question", "")
    if not question:
        return jsonify({"error": "question required"}), 400

    sources = await _search(question, body.get("top", 5))

    source_texts = [f"{s['source']}: {s['content']}" for s in sources]
    context = "\n\n".join(source_texts)

    client = await _refresh_openai()
    completion = await client.chat.completions.create(
        model=AZURE_OPENAI_CHAT_DEPLOYMENT,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Sources:\n{context}\n\nQuestion: {question}"},
        ],
        temperature=0.3,
        max_tokens=1024,
    )

    return jsonify({
        "answer": completion.choices[0].message.content,
        "sources": [
            {"source": s["source"], "score": round(s["score"], 4), "content": s["content"][:200]}
            for s in sources
        ],
    })


@app.route("/health")
async def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")), debug=True)
