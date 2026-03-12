#!/usr/bin/env python3
"""
Скрипт для чанкования файла с триггерными словами.
Разбивает большой текстовый файл на чанки для векторной базы данных.
"""

import os
import sys
from pathlib import Path
from typing import List, Dict

# Конфигурация
CHUNK_SIZE = 50  # Максимальное количество строк в чанке
OVERLAP = 10     # Перекрытие между чанками (для контекста)


def read_trigger_words(filepath: str) -> List[str]:
    """
    Читает файл с триггерными словами.

    Args:
        filepath: Путь к файлу.

    Returns:
        Список строк файла.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Удаляем пустые строки и комментарии
    cleaned = []
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith('#'):
            cleaned.append(stripped)
    
    return cleaned


def create_chunks(
    lines: List[str],
    chunk_size: int = CHUNK_SIZE,
    overlap: int = OVERLAP
) -> List[Dict]:
    """
    Создаёт чанки из списка строк с перекрытием.

    Args:
        lines: Список строк.
        chunk_size: Размер чанка (кол-во строк).
        overlap: Перекрытие между чанками.

    Returns:
        Список чанков с метаданными.
    """
    chunks = []
    start = 0
    chunk_id = 1

    while start < len(lines):
        end = min(start + chunk_size, len(lines))
        chunk_lines = lines[start:end]

        # Создаём чанк
        chunk = {
            'id': chunk_id,
            'start_line': start + 1,  # 1-based для удобства
            'end_line': end,
            'content': '\n'.join(chunk_lines),
            'word_count': len(chunk_lines),
        }

        # Добавляем категорию (если есть заголовок секции)
        if start > 0 and start < len(lines):
            # Пытаемся найти заголовок секции в предыдущих строках
            for i in range(max(0, start - 20), start):
                if i < len(lines):
                    # Простая эвристика: заголовок содержит буквы в верхнем регистре
                    prev_line = lines[i].strip() if i < len(lines) else ''
                    if prev_line and prev_line.isupper():
                        chunk['category'] = prev_line
                        break

        chunks.append(chunk)
        chunk_id += 1

        # Двигаемся с учётом перекрытия
        start = end - overlap
        if start >= len(lines):
            break

    return chunks


def save_chunks(chunks: List[Dict], output_dir: str) -> None:
    """
    Сохраняет чанки в отдельные файлы.

    Args:
        chunks: Список чанков.
        output_dir: Директория для сохранения.
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Сохраняем каждый чанк в отдельный файл
    for chunk in chunks:
        filename = f"chunk_{chunk['id']:03d}.txt"
        filepath = output_path / filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(f"# Chunk {chunk['id']}\n")
            f.write(f"# Lines: {chunk['start_line']} - {chunk['end_line']}\n")
            if 'category' in chunk:
                f.write(f"# Category: {chunk['category']}\n")
            f.write("\n")
            f.write(chunk['content'])
        
        print(f"   ✓ {filename} ({chunk['word_count']} слов)")

    # Сохраняем метаданные
    metadata = {
        'total_chunks': len(chunks),
        'chunks': chunks,
    }
    
    import json
    metadata_path = output_path / "metadata.json"
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    print(f"\n📄 metadata.json создан")


def print_summary(chunks: List[Dict], input_file: str) -> None:
    """Выводит сводку о чанковании."""
    total_words = sum(c['word_count'] for c in chunks)
    categories = set(c.get('category', 'Unknown') for c in chunks)
    
    print("\n" + "=" * 60)
    print("📊 СВОДКА ПО ЧАНКОВАНИЮ")
    print("=" * 60)
    print(f"📁 Входной файл: {input_file}")
    print(f"📦 Всего чанков: {len(chunks)}")
    print(f"📝 Всего слов: {total_words}")
    print(f"📏 Размер чанка: ~{CHUNK_SIZE} строк")
    print(f"🔗 Перекрытие: {OVERLAP} строк")
    print(f"📂 Категорий: {len(categories)}")
    print("\nКатегории:")
    for cat in sorted(categories):
        count = sum(1 for c in chunks if c.get('category') == cat)
        print(f"   • {cat}: {count} чанков")
    print("=" * 60)


def main():
    """Точка входа скрипта."""
    # Пути по умолчанию
    default_input = "assets/trigger_words_rankings.txt"
    default_output = "data/chunks/trigger_words"

    # Парсинг аргументов командной строки
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    else:
        input_file = default_input

    if len(sys.argv) > 2:
        output_dir = sys.argv[2]
    else:
        output_dir = default_output

    # Проверка входного файла
    if not os.path.exists(input_file):
        print(f"❌ Файл не найден: {input_file}")
        sys.exit(1)

    print(f"🚀 Чанкование файла: {input_file}")
    print(f"📁 Выходная директория: {output_dir}")
    print()

    # Чтение файла
    print("📖 Чтение файла...")
    lines = read_trigger_words(input_file)
    print(f"   Найдено {len(lines)} строк (без комментариев)")

    # Создание чанков
    print("\n✂️ Создание чанков...")
    chunks = create_chunks(lines)

    # Сохранение
    print("\n💾 Сохранение чанков...")
    save_chunks(chunks, output_dir)

    # Сводка
    print_summary(chunks, input_file)

    print("\n✅ Чанкование завершено!")
    print(f"\n📋 Для загрузки в векторную базу используйте:")
    print(f"   python scripts/embed_chunks.py {output_dir}")


if __name__ == "__main__":
    main()
