# Qwen2.5-1.5B Local API

Локальный API сервер для запуска модели Qwen2.5-1.5B-Instruct на вашем компьютере.

## 📦 Установка

### 1. Установите зависимости

```bash
pip install -r requirements.txt
```

Или вручную:
```bash
pip install llama-cpp-python flask flask-cors
```

### 2. Скачайте модель (если ещё не скачали)

```bash
python scripts/download_qwen.py
```

Модель будет загружена в: `models/qwen2.5-1.5b-instruct-gguf/Qwen2.5-1.5B-Instruct-Q8_0.gguf`

**Размер модели:** ~1.7 GB  
**Требования к RAM:** ~2-3 GB

## 🚀 Запуск сервера

```bash
python scripts/qwen_api.py
```

Сервер запустится на: `http://127.0.0.1:5000`

## 📡 API Endpoints

### GET /health
Проверка доступности API.

**Ответ:**
```json
{
  "status": "ok",
  "model": "Qwen2.5-1.5B-Instruct",
  "loaded": true
}
```

### POST /chat
Отправка запроса к чат-боту.

**Запрос:**
```json
{
  "message": "Привет! Расскажи о рейтинге UEFA.",
  "max_tokens": 512,
  "temperature": 0.7
}
```

**Ответ:**
```json
{
  "response": "Рейтинг UEFA клубов определяет...",
  "model": "Qwen2.5-1.5B-Instruct",
  "tokens_used": 128
}
```

### POST /generate
Генерация текста (без системного промпта).

**Запрос:**
```json
{
  "prompt": "Напиши краткий анализ матча...",
  "max_tokens": 256
}
```

## 🔧 Настройка

В начале файла `qwen_api.py` можно изменить параметры:

```python
MODEL_PATH = "models/qwen2.5-1.5b-instruct-gguf/Qwen2.5-1.5B-Instruct-Q8_0.gguf"
HOST = "127.0.0.1"
PORT = 5000
MAX_TOKENS = 512
TEMPERATURE = 0.7
```

### Параметры генерации:

- **max_tokens**: Максимальное количество токенов в ответе (1-2048)
- **temperature**: Креативность (0.0 = детерминировано, 1.0 = креативно)
- **n_ctx**: Размер контекста (по умолчанию 2048)
- **n_threads**: Количество потоков CPU (по умолчанию 4)

## 📊 Производительность

**На среднем ноутбуке (CPU, 8GB RAM):**
- Загрузка модели: ~30-60 секунд
- Генерация ответа: ~5-15 секунд (в зависимости от длины)

**На компьютере с GPU (NVIDIA):**
- Измените `n_gpu_layers=35` в `load_model()` для ускорения

## ⚠️ Возможные проблемы

### 1. Ошибка "Model not found"
Убедитесь, что модель скачана:
```bash
python scripts/download_qwen.py
```

### 2. Ошибка "llama-cpp-python not installed"
Установите с правильными флагами для вашей системы:

**Windows:**
```bash
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu
```

**Linux/Mac:**
```bash
CMAKE_ARGS="-DLLAMA_BLAS=ON" pip install llama-cpp-python
```

### 3. Медленная генерация
- Уменьшите `max_tokens`
- Увеличьте `n_threads`
- Используйте GPU (если есть)

## 🔗 Интеграция с Flutter

Flutter приложение автоматически подключается к этому API.

Если сервер не запущен, чат работает в тестовом режиме.

## 📝 Примеры запросов

```bash
# Проверка доступности
curl http://127.0.0.1:5000/health

# Запрос к чат-боту
curl -X POST http://127.0.0.1:5000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Какой клуб возглавляет рейтинг UEFA?"}'
```

## 🛑 Остановка сервера

Нажмите `Ctrl+C` в терминале.
