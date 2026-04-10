#!/usr/bin/env python3
"""
Локальный API сервер для Qwen2.5-1.5B-Instruct GGUF с поиском в интернете.
Использует llama-cpp-python для модели и DuckDuckGo для поиска.

Запуск:
    python scripts/qwen_api.py

Зависимости:
    pip install llama-cpp-python flask flask-cors
    pip install langchain langchain-community duckduckgo-search  (для поиска)
"""

import sys
import os
from pathlib import Path

try:
    from llama_cpp import Llama
except ImportError:
    print("[ERROR] llama-cpp-python не установлена!")
    print("  pip install llama-cpp-python")
    sys.exit(1)

try:
    from flask import Flask, request, jsonify
    from flask_cors import CORS
except ImportError:
    print("[ERROR] Flask не установлен!")
    print("  pip install flask flask-cors")
    sys.exit(1)

try:
    from langchain_community.utilities import DuckDuckGoSearchAPIWrapper
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False

MODEL_PATH = "models/qwen/Qwen2.5-1.5B-Instruct-Q5_K_M.gguf"
HOST = "127.0.0.1"
PORT = 5000
MAX_TOKENS = 512
TEMPERATURE = 0.7
SEARCH_RESULTS = 3

app = Flask(__name__)
CORS(app)

llm = None
search = None


def load_model():
    global llm
    model_file = Path(MODEL_PATH)
    if not model_file.exists():
        print(f"[ERROR] Модель не найдена: {MODEL_PATH}")
        print("Сначала запустите: python scripts/download_qwen.py")
        return False
    print(f"[INFO] Загрузка модели: {MODEL_PATH}")
    try:
        llm = Llama(
            model_path=str(model_file),
            n_ctx=4096,
            n_threads=4,
            n_gpu_layers=0,
            verbose=False,
        )
        print("[OK] Модель загружена успешно!")
        return True
    except Exception as e:
        print(f"[ERROR] Ошибка загрузки модели: {e}")
        return False


def init_search():
    global search
    if LANGCHAIN_AVAILABLE:
        try:
            search = DuckDuckGoSearchAPIWrapper(max_results=SEARCH_RESULTS)
            print("[OK] DuckDuckGo Search инициализирован")
            return True
        except Exception as e:
            print(f"[WARN] Ошибка инициализации поиска: {e}")
            search = None
    return False


def search_web(query):
    if search is None:
        return ""
    try:
        print(f"[SEARCH] Поиск: {query}")
        results = search.results(query, SEARCH_RESULTS)
        if not results:
            print("[SEARCH] Результаты не найдены")
            return ""
        parts = []
        for i, r in enumerate(results[:SEARCH_RESULTS], 1):
            title = r.get("title", "")
            snippet = r.get("snippet", "")
            link = r.get("link", "")
            parts.append(f"[Источник {i}]\nЗаголовок: {title}\n{snippet}\nURL: {link}")
        print(f"[SEARCH] Найдено {len(results)} результатов")
        return "\n\n".join(parts)
    except Exception as e:
        print(f"[SEARCH] Ошибка поиска: {e}")
        return ""


@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "ok",
        "model": "Qwen2.5-1.5B-Instruct",
        "loaded": llm is not None,
        "search_available": search is not None,
        "langchain": LANGCHAIN_AVAILABLE,
    })


@app.route("/chat", methods=["POST"])
def chat():
    if llm is None:
        return jsonify({"error": "Model not loaded"}), 503
    data = request.get_json()
    if not data or "message" not in data:
        return jsonify({"error": "Message is required"}), 400
    message = data["message"]
    max_tokens = data.get("max_tokens", MAX_TOKENS)
    temperature = data.get("temperature", TEMPERATURE)
    use_search = data.get("use_search", False)
    print(f"[REQUEST] Запрос: {message} (search={use_search})")
    try:
        web_context = ""
        if use_search and search is not None:
            web_context = search_web(message)
        if web_context:
            prompt = (
                f"<|system|>\n"
                f"Ты — Sportsense AI. Ниже приведена АКТУАЛЬНАЯ информация из интернета.\n\n"
                f"=== НАЧАЛО ДАННЫХ ИЗ ИНТЕРНЕТА ===\n"
                f"{web_context}\n"
                f"=== КОНЕЦ ДАННЫХ ИЗ ИНТЕРНЕТА ===\n\n"
                f"ПРАВИЛА:\n"
                f"1. ОТВЕЧАЙ НА РУССКОМ ЯЗЫКЕ.\n"
                f"2. Используй ТОЛЬКО данные из блока выше. НЕ используй свои старые знания.\n"
                f"3. НЕ говори что не знаешь — информация УЖЕ предоставлена выше.\n"
                f"4. НЕ упоминай дату своего обучения. Данные выше — самые свежие.\n"
                f"5. Перескажи информацию своими словами, опираясь на источники.\n"
                f"6. В конце ответа напиши:\n"
                f"   ---\n"
                f"   Источники:\n"
                f"   [1] Заголовок — URL\n"
                f"<|user|>\n{message}\n"
                f"<|assistant|>\n"
            )
        else:
            prompt = (
                f"<|system|>\n"
                f"Ты полезный ассистент Sportsense AI, специализирующийся на спортивной аналитике.\n"
                f"<|user|>\n{message}\n"
                f"<|assistant|>\n"
            )
        output = llm(
            prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            stop=["<|user|>", "<|system|>"],
            echo=False,
        )
        response_text = output["choices"][0]["text"].strip()
        print(f"[RESPONSE] {response_text}")

        # Парсим источники для frontend
        sources = []
        if web_context:
            for part in web_context.split("\n\n"):
                if part.startswith("[Источник"):
                    lines = part.strip().split("\n")
                    title = ""
                    url = ""
                    for line in lines:
                        if line.startswith("Заголовок:"):
                            title = line.replace("Заголовок:", "").strip()
                        elif line.startswith("URL:"):
                            url = line.replace("URL:", "").strip()
                    if title or url:
                        sources.append({"title": title, "url": url})

        return jsonify({
            "response": response_text,
            "model": "Qwen2.5-1.5B-Instruct",
            "tokens_used": output["usage"]["total_tokens"],
            "search_used": use_search and web_context != "",
            "sources": sources,
        })
    except Exception as e:
        print(f"[ERROR] Ошибка генерации: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/generate", methods=["POST"])
def generate():
    if llm is None:
        return jsonify({"error": "Model not loaded"}), 503
    data = request.get_json()
    if not data or "prompt" not in data:
        return jsonify({"error": "Prompt is required"}), 400
    prompt = data["prompt"]
    max_tokens = data.get("max_tokens", MAX_TOKENS)
    try:
        output = llm(prompt, max_tokens=max_tokens, echo=False)
        return jsonify({
            "text": output["choices"][0]["text"],
            "tokens": output["usage"]["total_tokens"],
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/generate_title", methods=["POST"])
def generate_title():
    if llm is None:
        return jsonify({"error": "Model not loaded"}), 503
    data = request.get_json()
    if not data or "message" not in data:
        return jsonify({"error": "Message is required"}), 400
    message = data["message"]
    try:
        prompt = (
            f"<|system|>\n"
            f"Сгенерируй короткое название чата (макс 5 слов) для этого сообщения. "
            f"Ответь только названием, без кавычек и объяснений.\n"
            f"<|user|>\n{message}\n"
            f"<|assistant|>\n"
        )
        output = llm(prompt, max_tokens=30, temperature=0.7, stop=["<|user|>"], echo=False)
        title = output["choices"][0]["text"].strip().replace('"', '').strip()
        return jsonify({"title": title})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    print("=" * 60)
    print("[Sportsense AI - Qwen2.5-1.5B Local API Server]")
    print("=" * 60)
    if not load_model():
        sys.exit(1)
    init_search()
    print(f"\n[WEB] Запуск сервера на http://{HOST}:{PORT}")
    print("Endpoints:")
    print("  GET  /health  - проверка доступности")
    print("  POST /chat    - запрос к чат-боту (use_search=true для поиска)")
    print("  POST /generate - генерация текста")
    print("  POST /generate_title - генерация названия чата")
    print("\nНажмите Ctrl+C для остановки")
    print("=" * 60)
    os.environ["FLASK_ENV"] = "production"
    app.run(host=HOST, port=PORT, debug=False)
