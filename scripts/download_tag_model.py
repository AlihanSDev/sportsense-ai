#!/usr/bin/env python3
"""
Скрипт для загрузки маленькой модели для генерации тегов чатов.
Используется Qwen2.5-0.5B-Instruct - компактная модель для простых задач.

Модель: Qwen/Qwen2.5-0.5B-Instruct (GGUF версия)
Размер: ~400 MB
Требования к RAM: ~1 GB
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


def download_tag_model(
    repo_id: str = "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
    filename: str = "qwen2.5-0.5b-instruct-q4_k_m.gguf",
    output_dir: str = "models/qwen2.5-0.5b-tag-generator"
) -> str:
    """
    Загружает маленькую модель для генерации тегов с HuggingFace.

    Args:
        repo_id: Идентификатор репозитория на HuggingFace.
        filename: Имя файла модели (квантование Q4_K_M - оптимальный баланс).
        output_dir: Локальная директория для сохранения модели.

    Returns:
        Путь к загруженному файлу модели.
    """
    print(f"🚀 Начало загрузки модели для генерации тегов: {repo_id}...")
    print(f"📄 Файл: {filename}")
    print(f"📁 Директория сохранения: {output_dir}")

    # Создаём директорию, если она не существует
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    try:
        # Проверяем доступные файлы в репозитории
        print("🔍 Проверка доступных файлов...")
        try:
            files = list_repo_files(repo_id=repo_id)
            gguf_files = [f for f in files if f.endswith('.gguf')]
            if gguf_files:
                print(f"   Доступные GGUF файлы: {len(gguf_files)}")
                for f in gguf_files[:5]:
                    print(f"      - {f}")
        except Exception as e:
            print(f"   Не удалось получить список файлов: {e}")

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
        print("\n💡 Попробуйте альтернативные модели:")
        print("   - Qwen/Qwen2.5-0.5B-Instruct (полная версия)")
        print("   - microsoft/Phi-3-mini-4k-instruct-gguf")
        sys.exit(1)


def create_tag_generator_config(output_dir: str, model_path: str):
    """Создает конфигурационный файл для генератора тегов."""
    config_path = os.path.join(output_dir, "config.json")
    
    config = {
        "model_type": "tag_generator",
        "model_path": model_path,
        "description": "Маленькая модель для генерации кратких названий чатов",
        "parameters": {
            "max_tokens": 50,
            "temperature": 0.3,
            "top_p": 0.9,
        },
        "supported_languages": ["ru", "en"],
        "use_cases": [
            "Генерация названий чатов",
            "Определение темы вопроса",
            "Создание тегов для категоризации"
        ]
    }
    
    import json
    with open(config_path, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    
    print(f"📝 Конфигурация сохранена: {config_path}")


def main():
    """Точка входа скрипта."""
    # Можно переопределить через аргументы командной строки
    if len(sys.argv) > 2:
        output_dir = sys.argv[1]
        filename = sys.argv[2]
    elif len(sys.argv) > 1:
        output_dir = sys.argv[1]
        filename = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    else:
        output_dir = "models/qwen2.5-0.5b-tag-generator"
        filename = "qwen2.5-0.5b-instruct-q4_k_m.gguf"

    model_path = download_tag_model(filename=filename, output_dir=output_dir)
    
    # Создаем конфигурацию
    create_tag_generator_config(output_dir, model_path)

    print("\n" + "="*60)
    print("📋 Информация о модели для генерации тегов:")
    print("="*60)
    print(f"   • Модель: Qwen2.5-0.5B-Instruct (GGUF)")
    print(f"   • Квантование: Q4_K_M (4-битное)")
    print(f"   • Размер: ~400 MB")
    print(f"   • Требуемая RAM: ~1 GB")
    print(f"   • Назначение: Генерация кратких названий чатов")
    print(f"   • Путь: {model_path}")
    print("="*60)
    
    print("\n✅ Модель готова к использованию!")
    print("💡 Интегрируйте модель в ChatTagGenerator через локальный API")


if __name__ == "__main__":
    main()