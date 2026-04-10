#!/usr/bin/env python3
with open('scripts/qwen_api_0.5.py', 'w', encoding='utf-8') as f:
    f.write("""#!/usr/bin/env python3
import sys
from pathlib import Path
from llama_cpp import Llama
from flask import Flask, request, jsonify
from flask_cors import CORS

MODEL_PATH = "models/qwen2.5-0.5b-tag-generator/qwen2.5-0.5b-instruct-q4_k_m.gguf"
HOST = "127.0.0.1"
PORT = 5002
MAX_TOKENS = 100

app = Flask(__name__)
CORS(app)
llm = None

def load_model():
    global llm
    if not Path(MODEL_PATH).exists():
        print("[ERROR] Model not found")
        return False
    print("[INFO] Loading model...")
    llm = Llama(model_path=MODEL_PATH, n_ctx=1024, n_threads=4, verbose=False)
    print("[OK] Model loaded")
    return True

@app.route("/health")
def health():
    return jsonify({"status": "ok", "loaded": llm is not None})

@app.route("/generate", methods=["POST"])
def generate():
    data = request.get_json()
    prompt = data.get("prompt", "")
    output = llm(prompt, max_tokens=data.get("max_tokens", MAX_TOKENS), echo=False)
    return jsonify({"text": output["choices"][0]["text"].strip()})

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    message = data.get("message", "")
    prompt = "user
" + message + "