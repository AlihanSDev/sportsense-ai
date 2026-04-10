#!/usr/bin/env python3
"""
Тест HuggingFace Inference API (Router).
Проверяет доступность моделей и отправку запросов.
"""

import os
import sys

# Загружаем .env
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("[WARN] python-dotenv не установлен, используем переменные окружения")

HF_TOKEN = os.environ.get("HF_TOKEN", "")
HF_MODEL = os.environ.get("HF_MODEL", "mistralai/Mistral-7B-Instruct-v0.3")

print("=" * 60)
print("TEST 1: HF_TOKEN check")
print("=" * 60)
if HF_TOKEN and HF_TOKEN.startswith("hf_"):
    print(f"✅ HF_TOKEN found: {HF_TOKEN[:8]}...{HF_TOKEN[-4:]}")
else:
    print(f"❌ HF_TOKEN not found or invalid: {HF_TOKEN[:10] if HF_TOKEN else 'empty'}")
    print("FIX: Add HF_TOKEN=hf_xxxx to your .env file")
    sys.exit(1)

print()
print("=" * 60)
print("TEST 2: Model name")
print("=" * 60)
print(f"   Model: {HF_MODEL}")

print()
print("=" * 60)
print("TEST 3: Direct API call to HF Router")
print("=" * 60)

try:
    import requests
except ImportError:
    print("❌ requests not installed. pip install requests")
    sys.exit(1)

url = "https://router.huggingface.co/v1/chat/completions"
headers = {
    "Authorization": f"Bearer {HF_TOKEN}",
    "Content-Type": "application/json",
}

# Тестовый запрос
payload = {
    "model": HF_MODEL,
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Say hello in one word."},
    ],
    "max_tokens": 20,
    "temperature": 0.7,
}

print(f"  Sending request to {url}")
print(f"  Model: {HF_MODEL}")

try:
    response = requests.post(url, headers=headers, json=payload, timeout=60)
    print(f"  Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        choice = data.get("choices", [{}])[0]
        message = choice.get("message", {})
        content = message.get("content", "")
        usage = data.get("usage", {})
        print(f"✅ SUCCESS!")
        print(f"  Response: {content}")
        print(f"  Tokens: {usage.get('total_tokens', '?')}")
    else:
        print(f"❌ FAILED!")
        print(f"  Error: {response.text}")
        
        if "model_not_supported" in response.text:
            print()
            print("  FIX: Model not supported by HF Router free tier.")
            print("  Try these models instead:")
            print("    - mistralai/Mistral-7B-Instruct-v0.3")
            print("    - Qwen/Qwen2.5-7B-Instruct")
            print("    - microsoft/Phi-3-mini-4k-instruct")
            print()
            print("  Update your .env file:")
            print(f"    HF_MODEL=mistralai/Mistral-7B-Instruct-v0.3")
except requests.exceptions.Timeout:
    print("❌ TIMEOUT (60s)")
except Exception as e:
    print(f"❌ ERROR: {e}")

print()
print("=" * 60)
print("TEST 4: List available models")
print("=" * 60)
try:
    resp = requests.get(
        "https://router.huggingface.co/v1/models",
        headers={"Authorization": f"Bearer {HF_TOKEN}"},
        timeout=15,
    )
    if resp.status_code == 200:
        data = resp.json()
        models = data.get("data", [])
        print(f"✅ Found {len(models)} available models:")
        for m in models[:10]:
            print(f"   - {m.get('id', 'unknown')}")
        if len(models) > 10:
            print(f"   ... and {len(models) - 10} more")
    else:
        print(f"❌ Status {resp.status_code}: {resp.text[:200]}")
except Exception as e:
    print(f"❌ Error: {e}")
