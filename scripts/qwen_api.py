#!/usr/bin/env python3
"""
Sportsense AI API Server.
- Local Qwen 1.5B (llama-cpp-python)
- HuggingFace Router API (Qwen 7B) with LangChain web search
"""
import sys, os, json
from pathlib import Path
from datetime import datetime

# Load .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # python-dotenv optional, .env vars still work if set in shell

try:
    from llama_cpp import Llama
except ImportError:
    pass

try:
    from flask import Flask, request, jsonify
    from flask_cors import CORS
except ImportError:
    print("[ERROR] Flask not installed"); sys.exit(1)

try:
    from langchain_community.utilities import DuckDuckGoSearchAPIWrapper
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False

try:
    import requests as req_lib
except ImportError:
    print("[ERROR] requests not installed"); sys.exit(1)

MODEL_PATH = "models/qwen/Qwen2.5-1.5B-Instruct-Q5_K_M.gguf"
HOST = "127.0.0.1"
PORT = 5000
SEARCH_RESULTS = 3
HF_BASE_URL = "https://router.huggingface.co/v1"
HF_TOKEN = os.environ.get("HF_TOKEN", "")
HF_MODEL = os.environ.get("HF_MODEL", "Qwen/Qwen3.5-9B")

app = Flask(__name__)
CORS(app)
llm = None
search = None

def load_model():
    global llm
    model_file = Path(MODEL_PATH)
    if not model_file.exists():
        return False
    try:
        llm = Llama(model_path=str(model_file), n_ctx=4096, n_threads=4, n_gpu_layers=0, verbose=False)
        print("[OK] Model loaded")
        return True
    except Exception as e:
        print(f"[ERROR] Model load error: {e}")
        return False

def init_search():
    global search
    if LANGCHAIN_AVAILABLE:
        try:
            search = DuckDuckGoSearchAPIWrapper(max_results=SEARCH_RESULTS)
            print("[OK] DuckDuckGo Search initialized")
            return True
        except Exception as e:
            print(f"[WARN] Search init error: {e}")
            search = None
    return False

def search_web(query):
    if search is None:
        return ""
    try:
        print(f"[SEARCH] Searching: {query}")
        results = search.results(query, SEARCH_RESULTS)
        if not results:
            return ""
        parts = []
        for i, r in enumerate(results[:SEARCH_RESULTS], 1):
            title = r.get("title", "")
            snippet = r.get("snippet", "")
            link = r.get("link", "")
            parts.append(f"[Source {i}]\nTitle: {title}\n{snippet}\nURL: {link}")
        print(f"[SEARCH] Found {len(results)} results")
        return "\n\n".join(parts)
    except Exception as e:
        print(f"[SEARCH] Error: {e}")
        return ""

def call_hf_api(message, use_search=False, max_tokens=1024, temperature=0.7):
    """Calls HF Router API with optional LangChain web search."""
    if not HF_TOKEN:
        return {"error": "HF_TOKEN not set"}, 503

    # Search via LangChain
    web_context = ""
    if use_search and search is not None:
        web_context = search_web(message)

    now = datetime.now()
    date_str = f"{now.day}.{now.month}.{now.year}"

    if web_context:
        system_prompt = (
            f"You are Sportsense AI, a smart sports assistant. Current date: {date_str}.\n\n"
            f"Here is ACTUAL information from the internet about the user's query:\n\n"
            f"=== BEGIN INTERNET DATA ===\n"
            f"{web_context}\n"
            f"=== END INTERNET DATA ===\n\n"
            f"RULES:\n"
            f"1. Respond in RUSSIAN language.\n"
            f"2. Use ONLY the data from the block above. Do NOT use your old knowledge.\n"
            f"3. Do NOT say you don't know — the information is ALREADY provided above.\n"
            f"4. Current date is {date_str}. Do NOT mention your training cutoff date.\n"
            f"5. Paraphrase the information in your own words based on sources.\n"
            f"6. At the end of your answer list sources:\n"
            f"   ---\n"
            f"   Sources:\n"
            f"   [1] Title — URL"
        )
    else:
        system_prompt = (
            f"You are Sportsense AI, a smart sports assistant. Current date: {date_str}.\n"
            f"You specialize in sports analytics, UEFA data, and football.\n"
            f"Respond in Russian. Be helpful and accurate."
        )

    try:
        print(f"[HF] Request to {HF_MODEL} (search={use_search})...")
        resp = req_lib.post(
            f"{HF_BASE_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {HF_TOKEN}",
                "Content-Type": "application/json",
            },
            json={
                "model": HF_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message},
                ],
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
            timeout=120,
        )

        if resp.status_code == 200:
            data = resp.json()
            choice = data.get("choices", [{}])[0]
            text = choice.get("message", {}).get("content", "")
            usage = data.get("usage", {})
            print(f"[HF] Response received ({usage.get('total_tokens', '?')} tokens)")
            return {
                "response": text,
                "model": HF_MODEL,
                "tokens_used": usage.get("total_tokens", 0),
                "search_used": use_search and web_context != "",
            }, 200
        else:
            print(f"[HF] Error {resp.status_code}: {resp.text}")
            return {"error": resp.text}, resp.status_code
    except Exception as e:
        print(f"[HF] Request error: {e}")
        return {"error": str(e)}, 500

@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "ok",
        "model": "Qwen2.5-1.5B-Instruct",
        "loaded": llm is not None,
        "search_available": search is not None,
        "langchain": LANGCHAIN_AVAILABLE,
        "hf_model": HF_MODEL if HF_TOKEN else None,
        "hf_available": bool(HF_TOKEN),
    })

@app.route("/search", methods=["POST"])
def web_search():
    """Search only, no LLM."""
    data = request.get_json()
    if not data or "query" not in data:
        return jsonify({"error": "Query is required"}), 400
    query = data["query"]
    context = search_web(query)
    return jsonify({
        "query": query,
        "web_context": context,
        "has_results": context != "",
    })

@app.route("/hf_chat", methods=["POST"])
def hf_chat():
    """HuggingFace API with LangChain web search."""
    data = request.get_json()
    if not data or "message" not in data:
        return jsonify({"error": "Message is required"}), 400
    message = data["message"]
    max_tokens = data.get("max_tokens", 1024)
    temperature = data.get("temperature", 0.7)
    use_search = data.get("use_search", False)
    result, status = call_hf_api(message, use_search, max_tokens, temperature)
    return jsonify(result), status

@app.route("/chat", methods=["POST"])
def chat():
    """Local Qwen 1.5B chat."""
    if llm is None:
        return jsonify({"error": "Model not loaded"}), 503
    data = request.get_json()
    if not data or "message" not in data:
        return jsonify({"error": "Message is required"}), 400
    message = data["message"]
    max_tokens = data.get("max_tokens", 512)
    temperature = data.get("temperature", 0.7)
    try:
        prompt = f"<|system|>\nYou are Sportsense AI.\n<|user|>\n{message}\n<|assistant|>\n"
        output = llm(prompt, max_tokens=max_tokens, temperature=temperature, stop=["<|user|>"], echo=False)
        response_text = output["choices"][0]["text"].strip()
        return jsonify({
            "response": response_text,
            "model": "Qwen2.5-1.5B-Instruct",
            "tokens_used": output["usage"]["total_tokens"],
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
        prompt = f"<|system|>\nGenerate a short chat title (5 words max). Only the title, no quotes.\n<|user|>\n{message}\n<|assistant|>\n"
        output = llm(prompt, max_tokens=30, temperature=0.7, stop=["<|user|>"], echo=False)
        title = output["choices"][0]["text"].strip().replace('"', '').strip()
        return jsonify({"title": title})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("=" * 60)
    print("[Sportsense AI - API Server]")
    print("=" * 60)
    load_model()
    init_search()
    print(f"\n[WEB] Server on http://{HOST}:{PORT}")
    print("Endpoints:")
    print("  GET  /health   - status")
    print("  POST /chat     - local Qwen 1.5B")
    print("  POST /hf_chat  - HF Router (Qwen 7B) + LangChain search")
    print("  POST /search   - search only")
    print("  POST /generate_title - title generation")
    print("=" * 60)
    os.environ["FLASK_ENV"] = "production"
    app.run(host=HOST, port=PORT, debug=False)
