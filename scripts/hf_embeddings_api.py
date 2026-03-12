#!/usr/bin/env python3
"""
Local API wrapper for Hugging Face embeddings and sentence similarity.
"""

import os
import sys
from typing import List

from flask import Flask, jsonify, request
from flask_cors import CORS

try:
    from huggingface_hub import InferenceClient
except ImportError:
    print("huggingface_hub is required. Install with: pip install huggingface_hub")
    sys.exit(1)


HOST = "127.0.0.1"
PORT = 5002
MODEL = os.environ.get(
    "HF_EMBEDDING_MODEL",
    "ibm-granite/granite-embedding-278m-multilingual",
)
PROVIDER = os.environ.get("HF_EMBEDDING_PROVIDER", "hf-inference")
API_KEY = os.environ.get("HF_TOKEN", "")

app = Flask(__name__)
CORS(app)

client = None


def get_client() -> InferenceClient:
    global client
    if client is None:
        if not API_KEY:
            raise RuntimeError("HF_TOKEN is not set")
        client = InferenceClient(provider=PROVIDER, api_key=API_KEY)
    return client


def _pool_embedding(raw_embedding) -> List[float]:
    if isinstance(raw_embedding, list) and raw_embedding and isinstance(raw_embedding[0], list):
        vector_size = len(raw_embedding[0])
        pooled = [0.0] * vector_size
        for token_vector in raw_embedding:
            for i, value in enumerate(token_vector):
                pooled[i] += float(value)
        token_count = max(len(raw_embedding), 1)
        return [value / token_count for value in pooled]

    return [float(value) for value in raw_embedding]


@app.route("/health", methods=["GET"])
def health():
    return jsonify(
        {
            "status": "ok" if API_KEY else "missing_token",
            "model": MODEL,
            "provider": PROVIDER,
            "has_token": bool(API_KEY),
        }
    )


@app.route("/embed", methods=["POST"])
def embed():
    payload = request.get_json(silent=True) or {}
    texts = payload.get("texts")
    if not isinstance(texts, list) or not texts:
        return jsonify({"error": "`texts` must be a non-empty list"}), 400

    try:
        inference = get_client()
        embeddings = []
        for text in texts:
            raw_embedding = inference.feature_extraction(text, model=MODEL)
            embeddings.append(_pool_embedding(raw_embedding))
        return jsonify({"model": MODEL, "embeddings": embeddings})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/similarity", methods=["POST"])
def similarity():
    payload = request.get_json(silent=True) or {}
    source_sentence = payload.get("source_sentence")
    sentences = payload.get("sentences")

    if not isinstance(source_sentence, str) or not source_sentence.strip():
        return jsonify({"error": "`source_sentence` must be a non-empty string"}), 400
    if not isinstance(sentences, list) or not sentences:
        return jsonify({"error": "`sentences` must be a non-empty list"}), 400

    try:
        inference = get_client()
        scores = inference.sentence_similarity(
            {
                "source_sentence": source_sentence,
                "sentences": sentences,
            },
            model=MODEL,
        )
        return jsonify({"model": MODEL, "scores": [float(score) for score in scores]})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    print("=" * 60)
    print("Sportsense HF Embeddings API")
    print("=" * 60)
    print(f"Model: {MODEL}")
    print(f"Provider: {PROVIDER}")
    print(f"Listening on http://{HOST}:{PORT}")
    print("Endpoints:")
    print("  GET  /health")
    print("  POST /embed")
    print("  POST /similarity")
    print("=" * 60)
    app.run(host=HOST, port=PORT, debug=False)
