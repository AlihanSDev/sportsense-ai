#!/usr/bin/env python3
"""Qwen 0.5B API - Minimal Version"""
import sys
import os
from pathlib import Path
from llama_cpp import Llama
from flask import Flask, request, jsonify
from flask_cors import CORS

MODEL = "models/qwen2.5-0.5b-tag-generator/qwen2.5-0.5b-instruct-q4_k_m.gguf"
app = Flask(__name__)
CORS(app)
llm = None

def load():
    global llm
    if not Path(MODEL).exists():
        print("[ERROR] Model not found")
        return False
    print("[INFO] Loading...")
    llm = Llama(MODEL, n_ctx=1024, n_threads=4, verbose=False)
    print("[OK] Loaded")
    return True

@app.route("/health")
def health():
    return jsonify({"loaded": llm is not None})

@app.route("/generate", methods=["POST"])
def generate():
    d = request.get_json()
    o = llm(d.get("prompt", ""), max_tokens=100, echo=False)
    return jsonify({"text": o["choices"][0]["text"].strip()})

@app.route("/chat", methods=["POST"])
def chat():
    d = request.get_json()
    m = d.get("message", "")
    o = llm(f"user\n{m}\nassistant\n", max_tokens=100, echo=False)
    return jsonify({"response": o["choices"][0]["text"].strip()})

@app.route("/generate_title", methods=["POST"])
def generate_title():
    d = request.get_json()
    m = d.get("message", "")
    prompt = f"Создай краткое название чата (максимум 5-6 слов) на основе этого вопроса. Только название, без кавычек.\n\nВопрос: \"{m}\"\n\nНазвание:"
    o = llm(prompt, max_tokens=30, echo=False)
    title = o["choices"][0]["text"].strip()
    # Убираем лишние кавычки и пробелы
    title = title.strip('"\'').strip()
    return jsonify({"title": title})

if __name__ == "__main__":
    print("="*50)
    print("[Sportsense AI - Qwen 0.5B Server]")
    print("="*50)
    if not load():
        sys.exit(1)
    port = int(os.environ.get('QWEN_PORT', 5002))
    print(f"[INFO] Running on http://127.0.0.1:{port}")
    app.run(host="127.0.0.1", port=port)
