# NLP Infrastructure Scripts

Скрипты для обработки текста и работы с векторной базой данных.

## 📋 Описание скриптов

### 1. `download_embeddings.py`
Загрузка модели эмбеддингов IBM Granite с HuggingFace.

```bash
python scripts/download_embeddings.py
```

**Выход:** `models/granite-embedding-278m-multilingual/`

---

### 2. `download_qwen.py`
Загрузка квантованной модели Qwen2.5-1.5B для локального чата.

```bash
python scripts/download_qwen.py
```

**Выход:** `models/qwen2.5-1.5b-instruct-gguf/Qwen2.5-1.5B-Instruct-Q8_0.gguf`

---

### 3. `chunk_trigger_words.py`
Разбиение файла с триггерными словами на чанки для векторной базы.

```bash
# По умолчанию
python scripts/chunk_trigger_words.py

# Своя директория
python scripts/chunk_trigger_words.py assets/trigger_words_rankings.txt data/chunks/my_chunks
```

**Параметры:**
- `CHUNK_SIZE = 50` строк в чанке
- `OVERLAP = 10` строк перекрытия

**Выход:** `data/chunks/trigger_words/chunk_*.txt` + `metadata.json`

---

### 4. `embed_chunks.py`
Создание эмбеддингов для чанков и сохранение для загрузки в БД.

```bash
# По умолчанию
python scripts/embed_chunks.py

# Своя директория чанков
python scripts/embed_chunks.py data/chunks/trigger_words

# Свой выходной файл
python scripts/embed_chunks.py data/chunks/trigger_words data/embeddings/my_embeddings.json
```

**Выход:** `data/embeddings/trigger_words_embeddings.json`

---

## 🔄 Полный пайплайн

```bash
# 1. Скачать модель эмбеддингов
python scripts/download_embeddings.py

# 2. Разбить триггерные слова на чанки
python scripts/chunk_trigger_words.py

# 3. Создать эмбеддинги
python scripts/embed_chunks.py

# 4. Загрузить в векторную базу (через Dart)
# Используйте VectorDatabaseManager в Flutter приложении
```

---

## 📦 Зависимости

```bash
pip install huggingface_hub sentence-transformers numpy
```

---

## 🗂️ Структура данных

```
data/
├── chunks/
│   └── trigger_words/
│       ├── chunk_001.txt
│       ├── chunk_002.txt
│       ├── ...
│       └── metadata.json
├── embeddings/
│   └── trigger_words_embeddings.json
└── vector_db/
    └── vector_db.json  # Локальная векторная БД
```

---

## 🔧 Конфигурация

Параметры чанкования можно изменить в начале `chunk_trigger_words.py`:

```python
CHUNK_SIZE = 50  # строк в чанке
OVERLAP = 10     # строк перекрытия
```

Параметры эмбеддингов в `embed_chunks.py`:

```python
BATCH_SIZE = 32  # размер батча для GPU/CPU
```
