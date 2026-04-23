#!/usr/bin/env python3
"""
LangChain-based search API that combines:
- HuggingFace Inference API (via OpenAI-compatible router)
- DuckDuckGo web search
- Optional RAG from vector database

Запуск:
    python scripts/langchain_search_api.py

Установка зависимостей:
    pip install -r requirements.txt  (или: pip install langchain langchain-openai langchain-community duckduckgo-search flask flask-cors python-dotenv)
"""

import os
import sys
from pathlib import Path

try:
    from flask import Flask, request, jsonify
    from flask_cors import CORS
except ImportError:
    print("❌ Flask не установлен!")
    print("Установите: pip install flask flask-cors")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    # Загружаем .env из корня проекта
    env_path = Path(__file__).parent.parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)
        print(f"✓ Загружены переменные окружения из {env_path}")
except ImportError:
    print("⚠ python-dotenv не установлен, переменные окружения берутся из системы")

try:
    from langchain_openai import ChatOpenAI
    from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
    from langchain_core.messages import SystemMessage, HumanMessage
    from langchain_community.tools import DuckDuckGoSearchResults
except ImportError as e:
    print(f"❌ LangChain библиотеки не установлены: {e}")
    print("Установите командой:")
    print("  pip install langchain langchain-openai langchain-community")
    sys.exit(1)

# ===================== КОНФИГУРАЦИЯ =====================
HF_TOKEN = os.getenv("HF_TOKEN", "")
HF_BASE_URL = os.getenv("HF_BASE_URL", "https://router.huggingface.co/v1")
DEFAULT_MODEL = os.getenv(
    "HF_DEFAULT_MODEL", "deepseek-ai/DeepSeek-R1-0528-Qwen3-8B:featherless-ai"
)
HOST = os.getenv("LANGCHAIN_API_HOST", "127.0.0.1")
PORT = int(os.getenv("LANGCHAIN_API_PORT", "5002"))

# Проверка токена
if not HF_TOKEN:
    print("⚠ HF_TOKEN не найден в переменных окружения. Укажите его в .env или установите как переменную окружения.")

# ===================== FLASK APP =====================
app = Flask(__name__)
CORS(app)

# ===================== LLM =====================
print(f"🤖 Инициализация LLM через HuggingFace Router...")
print(f"   Base URL: {HF_BASE_URL}")
print(f"   Model: {DEFAULT_MODEL}")

llm = ChatOpenAI(
    model=DEFAULT_MODEL,
    base_url=HF_BASE_URL,
    api_key=HF_TOKEN,
    temperature=0.7,
    max_tokens=512,
)

# ===================== SEARCH TOOL =====================
print("🔍 Инициализация DuckDuckGo search tool...")
search_tool = DuckDuckGoSearchResults(
    max_results=5,  # ограничиваем количество результатов
    backend="html",  # используем HTML-бэкенд (более стабильный)
)

# ===================== PROMPTS =====================
NON_SEARCH_SYSTEM = """You are SportSense AI - a brief football assistant.

RULES:
1. Answer in 1-2 sentences MAXIMUM
2. NO explanations of your thinking
3. NO internal monologue or annotations
4. NO <environment_details> or XML tags
5. Start with the answer directly
6. If you don't know - say "Не знаю" briefly
7. Focus on UEFA rankings, football clubs, and tournaments"""

SEARCH_SYSTEM = """You are SportSense AI - a brief football assistant. Use web search results to answer the user's question.

INSTRUCTIONS:
1. Answer in 1-2 sentences MAXIMUM
2. Base your answer on the search results provided
3. Cite sources if possible
4. If search results don't contain relevant info, use your knowledge and briefly state it's common knowledge
5. NO explanations, monologues, or XML tags
6. Start directly with the answer"""

SEARCH_PROMPT_TEMPLATE = ChatPromptTemplate.from_messages([
    ("system", SEARCH_SYSTEM),
    ("system", "Web search results:\n{search_results}"),
    ("user", "{question}"),
])

NON_SEARCH_PROMPT_TEMPLATE = ChatPromptTemplate.from_messages([
    ("system", NON_SEARCH_SYSTEM),
    ("user", "{question}"),
])

# ===================== ENDPOINTS =====================
@app.route('/health', methods=['GET'])
def health():
    """Проверка доступности сервиса."""
    return jsonify({
        'status': 'ok',
        'service': 'LangChain Search API',
        'model': DEFAULT_MODEL,
        'llm_initialized': llm is not None,
    })


@app.route('/chat', methods=['POST'])
def chat():
    """
    Основной чат-эндпоинт.

    Ожидаемый JSON:
    {
        "message": "string",
        "use_search": boolean,
        "max_tokens": int (optional),
        "temperature": float (optional)
    }
    """
    if llm is None:
        return jsonify({'error': 'LLM not initialized'}), 503

    data = request.get_json()
    if not data or 'message' not in data:
        return jsonify({'error': 'Message is required'}), 400

    user_message = data['message']
    use_search = data.get('use_search', False)
    max_tokens = data.get('max_tokens', 512)
    temperature = data.get('temperature', 0.7)

    # Ограничиваем max_tokens до 1024 для безопасности
    max_tokens = min(max_tokens, 1024)

    print(f"📥 Запрос: '{user_message[:60]}...' (search={use_search})")

    try:
        if use_search:
            # Выполняем веб-поиск
            print("🔍 Выполняем DuckDuckGo поиск...")
            try:
                search_results = search_tool.run(user_message)
                # Ограничиваем размер контекста поиска
                if len(search_results) > 3000:
                    search_results = search_results[:3000] + "... [truncated]"
                print(f"✓ Получено {len(search_results)} символов результатов поиска")
            except Exception as e:
                print(f"⚠ Ошибка поиска: {e}")
                search_results = "Не удалось получить результаты поиска. Отвечайте на основе общих знаний."

            # Формируем промпт с результатами поиска
            prompt = SEARCH_PROMPT_TEMPLATE.format_messages(
                search_results=search_results,
                question=user_message,
            )
        else:
            # Обычный чат без поиска
            prompt = NON_SEARCH_PROMPT_TEMPLATE.format_messages(question=user_message)

        # Вызываем LLM
        response = llm.invoke(prompt)
        answer = response.content

        # Очистка ответа
        answer = _clean_response(answer)

        print(f"📤 Ответ: {answer[:100]}...")

        return jsonify({
            'response': answer,
            'model': DEFAULT_MODEL,
            'used_search': use_search,
            'reasoning': None,  # reasoning извлекается в Dart из专门 поля, здесь не используем
        })

    except Exception as e:
        print(f"❌ Ошибка генерации: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


def _clean_response(text: str) -> str:
    """Очистка ответа от артефактов."""
    # Удаляем XML-теги если просочились
    import re
    text = re.sub(r'<[^>]+>', '', text)
    # Удаляем лишние пробелы
    text = text.strip()
    # Ограничиваем длину
    if len(text) > 1000:
        text = text[:997] + "..."
    return text


if __name__ == '__main__':
    print("=" * 60)
    print("🔎 Sportsense - LangChain Search API")
    print("=" * 60)
    print(f"🤖 Model: {DEFAULT_MODEL}")
    print(f"🌐 Router: {HF_BASE_URL}")
    print(f"🔍 Search: DuckDuckGo")
    print(f"🚀 Server: http://{HOST}:{PORT}")
    print("Endpoints:")
    print("  GET  /health  - health check")
    print("  POST /chat    - chat with optional web search")
    print("=" * 60)
    print("\nНажмите Ctrl+C для остановки\n")

    try:
        app.run(host=HOST, port=PORT, debug=False, threaded=True)
    except KeyboardInterrupt:
        print("\n👋 Сервис остановлен")
        sys.exit(0)
