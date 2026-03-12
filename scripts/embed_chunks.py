#!/usr/bin/env python3
"""
Скрипт для создания эмбеддингов чанков и загрузки в векторную базу данных.
Использует локальную модель granite-embedding-278m-multilingual.
"""

import os
import sys
import json
from pathlib import Path
from typing import List, Dict

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    print("❌ Библиотека sentence-transformers не установлена.")
    print("Установите её командой:")
    print("  pip install sentence-transformers")
    sys.exit(1)

try:
    import numpy as np
except ImportError:
    print("❌ Библиотека numpy не установлена.")
    print("Установите её командой:")
    print("  pip install numpy")
    sys.exit(1)


# Конфигурация
EMBEDDING_MODEL = "models/granite-embedding-278m-multilingual"
BATCH_SIZE = 32  # Размер батча для эмбеддингов


def load_model(model_path: str) -> SentenceTransformer:
    """
    Загружает модель эмбеддингов.

    Args:
        model_path: Путь к модели.

    Returns:
        Загруженная модель.
    """
    if not os.path.exists(model_path):
        print(f"❌ Модель не найдена: {model_path}")
        print("Сначала запустите: python scripts/download_embeddings.py")
        sys.exit(1)

    print(f"🤖 Загрузка модели: {model_path}")
    model = SentenceTransformer(model_path)
    print(f"   ✓ Модель загружена (размер вектора: {model.get_sentence_embedding_dimension()})")
    return model


def load_chunks(chunks_dir: str) -> List[Dict]:
    """
    Загружает чанки из директории.

    Args:
        chunks_dir: Директория с чанками.

    Returns:
        Список чанков.
    """
    chunks_path = Path(chunks_dir)
    
    if not chunks_path.exists():
        print(f"❌ Директория не найдена: {chunks_dir}")
        sys.exit(1)

    # Читаем метаданные
    metadata_file = chunks_path / "metadata.json"
    if not metadata_file.exists():
        print(f"❌ metadata.json не найден в {chunks_dir}")
        sys.exit(1)

    with open(metadata_file, 'r', encoding='utf-8') as f:
        metadata = json.load(f)

    chunks = metadata.get('chunks', [])
    print(f"📦 Загружено {len(chunks)} чанков")
    
    return chunks


def create_embeddings(
    model: SentenceTransformer,
    chunks: List[Dict],
    batch_size: int = BATCH_SIZE
) -> List[Dict]:
    """
    Создаёт эмбеддинги для чанков.

    Args:
        model: Модель эмбеддингов.
        chunks: Список чанков.
        batch_size: Размер батча.

    Returns:
        Чанки с добавленными эмбеддингами.
    """
    print(f"\n⚙️ Генерация эмбеддингов (батч: {batch_size})...")
    
    texts = [chunk['content'] for chunk in chunks]
    
    # Генерация эмбеддингов батчами
    embeddings = model.encode(
        texts,
        batch_size=batch_size,
        show_progress_bar=True,
        convert_to_numpy=True,
    )

    # Добавляем эмбеддинги к чанкам
    for i, chunk in enumerate(chunks):
        chunk['embedding'] = embeddings[i].tolist()
    
    print(f"   ✓ Эмбеддинги созданы")
    return chunks


def save_embeddings(chunks: List[Dict], output_file: str) -> None:
    """
    Сохраняет чанки с эмбеддингами в файл.

    Args:
        chunks: Чанки с эмбеддингами.
        output_file: Путь к выходному файлу.
    """
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Сохраняем без полных эмбеддингов (для просмотра)
    preview = []
    for chunk in chunks:
        preview_chunk = {k: v for k, v in chunk.items() if k != 'embedding'}
        preview_chunk['embedding_size'] = len(chunk['embedding'])
        preview.append(preview_chunk)

    preview_file = output_path.with_name(f"{output_path.stem}_preview{output_path.suffix}")
    with open(preview_file, 'w', encoding='utf-8') as f:
        json.dump(preview, f, indent=2, ensure_ascii=False)
    
    print(f"📄 Preview сохранён: {preview_file}")

    # Сохраняем полные данные (для загрузки в БД)
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(chunks, f, indent=2, ensure_ascii=False)
    
    file_size = os.path.getsize(output_file) / (1024 * 1024)
    print(f"💾 Данные сохранены: {output_file} ({file_size:.2f} MB)")


def main():
    """Точка входа скрипта."""
    # Пути по умолчанию
    default_chunks_dir = "data/chunks/trigger_words"
    default_output = "data/embeddings/trigger_words_embeddings.json"
    default_model = EMBEDDING_MODEL

    # Парсинг аргументов командной строки
    if len(sys.argv) > 1:
        chunks_dir = sys.argv[1]
    else:
        chunks_dir = default_chunks_dir

    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    else:
        output_file = default_output

    if len(sys.argv) > 3:
        model_path = sys.argv[3]
    else:
        model_path = default_model

    print(f"🚀 Создание эмбеддингов чанков")
    print(f"📁 Директория чанков: {chunks_dir}")
    print(f"📄 Выходной файл: {output_file}")
    print(f"🤖 Модель: {model_path}")
    print()

    # Загрузка модели
    model = load_model(model_path)

    # Загрузка чанков
    print()
    chunks = load_chunks(chunks_dir)

    # Создание эмбеддингов
    chunks_with_embeddings = create_embeddings(model, chunks)

    # Сохранение
    print()
    save_embeddings(chunks_with_embeddings, output_file)

    print("\n✅ Готово!")
    print(f"\n📋 Следующий шаг: загрузка в векторную базу")
    print(f"   Dart: Используйте VectorDatabaseManager")


if __name__ == "__main__":
    main()
