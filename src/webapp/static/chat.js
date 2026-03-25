// ----------------------------------------------------------------
//  AI Foundry RAG Chat — 프론트엔드
// ----------------------------------------------------------------
const messagesDiv = document.getElementById("messages");
const welcomeDiv = document.getElementById("welcomeMessage");
const userInput = document.getElementById("userInput");
const sendBtn = document.getElementById("sendBtn");
const chatContainer = document.getElementById("chatContainer");

let chatHistory = [];

// 자동 높이 조절
userInput.addEventListener("input", () => {
    userInput.style.height = "auto";
    userInput.style.height = Math.min(userInput.scrollHeight, 120) + "px";
});

function scrollToBottom() {
    chatContainer.scrollTop = chatContainer.scrollHeight;
}

// 예시 질문 클릭
function askExample(btn) {
    userInput.value = btn.textContent;
    sendMessage();
}

// 후속 질문 클릭
function askFollowup(text) {
    userInput.value = text;
    sendMessage();
}

// 메시지 추가
function addMessage(role, content, sources) {
    const msg = document.createElement("div");
    msg.className = `message ${role}`;

    const avatar = document.createElement("div");
    avatar.className = "avatar";
    avatar.textContent = role === "user" ? "👤" : "🤖";

    const bubble = document.createElement("div");
    bubble.className = "bubble";

    // 후속 질문 파싱 (<<...>>)
    let mainContent = content;
    const followups = [];
    const followupRegex = /<<(.+?)>>/g;
    let match;
    while ((match = followupRegex.exec(content)) !== null) {
        followups.push(match[1]);
    }
    mainContent = content.replace(/<<.+?>>/g, "").trim();

    // [source.pdf] 형태 하이라이트
    mainContent = mainContent.replace(
        /\[([^\]]+\.\w+)\]/g,
        '<span class="source-name">[$1]</span>'
    );

    bubble.innerHTML = mainContent;

    // 후속 질문 버튼
    if (followups.length > 0) {
        const followupDiv = document.createElement("div");
        followupDiv.style.marginTop = "10px";
        followups.forEach(q => {
            const btn = document.createElement("button");
            btn.className = "followup-btn";
            btn.textContent = q;
            btn.onclick = () => askFollowup(q);
            followupDiv.appendChild(btn);
        });
        bubble.appendChild(followupDiv);
    }

    // 소스 카드
    if (sources && sources.length > 0) {
        const details = document.createElement("details");
        details.className = "sources";
        const summary = document.createElement("summary");
        summary.textContent = `📎 참고 소스 (${sources.length}개)`;
        details.appendChild(summary);
        sources.forEach(s => {
            const item = document.createElement("div");
            item.className = "source-item";
            item.innerHTML = `<span class="source-name">${s.source}</span> <small>(score: ${s.score})</small><br/><small>${s.content}</small>`;
            details.appendChild(item);
        });
        bubble.appendChild(details);
    }

    msg.appendChild(avatar);
    msg.appendChild(bubble);
    messagesDiv.appendChild(msg);
    scrollToBottom();
}

// 로딩 표시
function showTyping() {
    const msg = document.createElement("div");
    msg.className = "message assistant";
    msg.id = "typingIndicator";

    const avatar = document.createElement("div");
    avatar.className = "avatar";
    avatar.textContent = "🤖";

    const bubble = document.createElement("div");
    bubble.className = "bubble typing-indicator";
    bubble.innerHTML = "<span></span><span></span><span></span>";

    msg.appendChild(avatar);
    msg.appendChild(bubble);
    messagesDiv.appendChild(msg);
    scrollToBottom();
}

function hideTyping() {
    const el = document.getElementById("typingIndicator");
    if (el) el.remove();
}

// 전송
async function sendMessage() {
    const text = userInput.value.trim();
    if (!text) return;

    // 환영 메시지 숨기기
    if (welcomeDiv) welcomeDiv.style.display = "none";

    // 사용자 메시지 표시
    addMessage("user", text);
    chatHistory.push({ role: "user", content: text });

    userInput.value = "";
    userInput.style.height = "auto";
    sendBtn.disabled = true;
    showTyping();

    try {
        const resp = await fetch("/chat", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                messages: chatHistory,
                top: 5,
                temperature: 0.3,
            }),
        });

        if (!resp.ok) {
            const err = await resp.json();
            throw new Error(err.error || `HTTP ${resp.status}`);
        }

        const data = await resp.json();
        hideTyping();

        addMessage("assistant", data.answer, data.sources);
        chatHistory.push({ role: "assistant", content: data.answer });
    } catch (e) {
        hideTyping();
        addMessage("assistant", `⚠️ 오류가 발생했습니다: ${e.message}`);
    } finally {
        sendBtn.disabled = false;
        userInput.focus();
    }
}

// 대화 초기화
function clearChat() {
    chatHistory = [];
    messagesDiv.innerHTML = "";
    if (welcomeDiv) welcomeDiv.style.display = "block";
}
