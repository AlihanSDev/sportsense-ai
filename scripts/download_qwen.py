#!/usr/bin/env python3
"""
Скрипт для загрузки квантованной модели Qwen2.5-1.5B-Instruct с HuggingFace.
Модель оптимизирована для запуска на ноутбуках с ограниченной памятью.

Модель: bartowski/Qwen2.5-1.5B-Instruct-GGUF (квантованная версия Q8_0)
Размер: ~1.7 GB
Требования к RAM: ~2-3 GB
"""

import os
import sys
from pathlib import Path

try:
    from huggingface_hub import hf_hub_download, list_repo_files
except ImportError:
    print("❌ Библиотека huggingface_hub не установлена.")
    print("Установите её командой:")
    print("  pip install huggingface_hub")
    sys.exit(1)


def download_qwen(
    repo_id: str = "bartowski/Qwen2.5-1.5B-Instruct-GGUF",
    filename: str = "Qwen2.5-1.5B-Instruct-Q8_0.gguf",
    output_dir: str = "models/qwen2.5-1.5b-instruct-gguf"
) -> str:
    """
    Загружает квантованную модель Qwen с HuggingFace.

    Args:
        repo_id: Идентификатор репозитория на HuggingFace.
        filename: Имя файла модели (квантование Q8_0 — баланс качества и размера).
        output_dir: Локальная директория для сохранения модели.

    Returns:
        Путь к загруженному файлу модели.
    """
    print(f"🚀 Начало загрузки модели {repo_id}...")
    print(f"📄 Файл: {filename}")
    print(f"📁 Директория сохранения: {output_dir}")

    # Создаём директорию, если она не существует
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    try:
        # Проверяем доступные файлы в репозитории
        print("🔍 Проверка доступных файлов...")
        files = list_repo_files(repo_id=repo_id)
        gguf_files = [f for f in files if f.endswith('.gguf')]
        if gguf_files:
            print(f"   Доступные GGUF файлы: {len(gguf_files)}")
            for f in gguf_files[:5]:
                print(f"      - {f}")

        # Загружаем файл модели
        model_path = hf_hub_download(
            repo_id=repo_id,
            filename=filename,
            local_dir=output_dir,
            resume_download=True,
        )
        print(f"✅ Модель успешно загружена: {model_path}")

        # Показываем размер файла
        size = os.path.getsize(model_path)
        size_mb = size / (1024 * 1024)
        print(f"📦 Размер: {size_mb:,.2f} MB")

        return model_path
    except Exception as e:
        print(f"❌ Ошибка при загрузке модели: {e}")
        sys.exit(1)


def main():
    """Точка входа скрипта."""
    # Можно переопределить через аргументы командной строки
    if len(sys.argv) > 2:
        output_dir = sys.argv[1]
        filename = sys.argv[2]
    elif len(sys.argv) > 1:
        output_dir = sys.argv[1]
        filename = "Qwen2.5-1.5B-Instruct-Q8_0.gguf"
    else:
        output_dir = "models/qwen2.5-1.5b-instruct-gguf"
        filename = "Qwen2.5-1.5B-Instruct-Q8_0.gguf"

    download_qwen(filename=filename, output_dir=output_dir)

    print("\n📋 Информация о модели:")
    print("   • Модель: Qwen2.5-1.5B-Instruct (GGUF)")
    print("   • Квантование: Q8_0 (8-битное)")
    print("   • Требуемая RAM: ~2-3 GB")
    print("   • Для запуска используйте llama-cpp-python или llamafile")


if __name__ == "__main__":
    main()
