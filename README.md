# Sportsense AI

Спортивное приложение с искусственным интеллектом, разработанное на Flutter.

## 📱 О проекте

Sportsense AI — это современное мобильное приложение для отслеживания спортивных активностей с использованием AI-технологий.

## 🚀 Возможности

- Интеграция с AI-сервисами для анализа спортивных данных
- Современный UI на базе Material Design
- Поддержка платформ: Android, iOS, Web, Windows, Linux, macOS

## 🛠 Технологии

- **Flutter** — кроссплатформенная разработка
- **Dart SDK** — ^3.11.0
- **google_fonts** — кастомные шрифты
- **http** — HTTP-запросы к API
- **flutter_dotenv** — управление переменными окружения

## 📦 Установка

1. Клонируйте репозиторий:
```bash
git clone https://github.com/AlihanSDev/sportsense-ai.git
cd sportsense-ai
```

2. Установите зависимости:
```bash
flutter pub get
```

3. Настройте переменные окружения:
```bash
cp .env.example .env
```

4. Запустите приложение:
```bash
flutter run
```

## ⚙️ Настройка

Создайте файл `.env` в корневой директории и добавьте необходимые переменные окружения (API ключи, эндпоинты и т.д.).

## 🏗 Структура проекта

```
sportsense-ai/
├── lib/              # Исходный код приложения
├── android/          # Android-специфичные файлы
├── ios/              # iOS-специфичные файлы
├── web/              # Web-специфичные файлы
├── windows/          # Windows-специфичные файлы
├── linux/            # Linux-специфичные файлы
├── macos/            # macOS-специфичные файлы
├── test/             # Тесты
└── .env.example      # Пример переменных окружения
```

## 🧪 Тестирование

```bash
flutter test
```

## 📰 UEFA Parser Module

В проект добавлен утилитный модуль, который вытаскивает "недавние" матчи с главной страницы
[uefa.com](https://www.uefa.com/). Парсер реализован в
`lib/services/uefa_parser.dart`, а точка запуска — в `bin/uefa_parser.dart`.

### Как запустить

1. Обновите зависимости (если ещё не сделали):
   ```bash
   cd c:/MyFlutterProjects/sportsense-ai/sportsense
   flutter pub get
   ```
2. Выполните скрипт:
   ```bash
   dart run bin/uefa_parser.dart
   # или `flutter pub run bin/uefa_parser.dart`
   ```
   **Требуется установленный Chrome/Chromium** (парсер использует пакет
   `puppeteer` для рендеринга). Если браузер не найден, скрипт выбросит ошибку.

4. В рабочей директории появятся два файла:
   * `recent_matches.txt` – найденные последние матчи,
   * `rankings.txt` – строки таблицы ранкингов.

   Оба файла хранят данные в простом текстовом формате, второй выводит каждую
   строку как пары `col-id:значение`.

> ⚠️ Парсер использует простые эвристики для извлечения строк с командами. HTML
> структура сайта может измениться, и тогда придётся обновить логику.

## 🚀 ПОЛНЫЙ ЗАПУСК ПРОЕКТА С ЭМУЛЯТОРОМ

### Предварительные требования

1. **Flutter SDK** установлен и настроен
2. **Android SDK** с эмуляторами
3. **Python 3.8+** с виртуальным окружением
4. **Git** для клонирования

### Шаг 1: Клонирование и настройка

```bash
git clone https://github.com/AlihanSDev/sportsense-ai.git
cd sportsense-ai/sportsense
```

### Шаг 2: Настройка Flutter

```bash
flutter pub get
```

### Шаг 3: Настройка Python окружения

```bash
# Создаем виртуальное окружение (если не существует)
python -m venv .venv

# Активируем
# Windows PowerShell:
& .\.venv\Scripts\Activate.ps1

# Linux/Mac:
# source .venv/bin/activate

# Устанавливаем зависимости
pip install -r scripts/requirements.txt

# Устанавливаем Playwright браузеры
python -m playwright install
```

### Шаг 4: Загрузка AI моделей (опционально)

```bash
# Модель эмбеддингов
python scripts/download_embeddings.py

# Qwen модель для чата (большая, ~1.5GB)
python scripts/download_qwen.py
```

### Шаг 5: ПОЛНАЯ КОМАНДА ЗАПУСКА (ИСПРАВЛЕНА)

**ОДНА КОМАНДА ДЛЯ ВСЕГО (с Small Phone эмулятором):**

```powershell
cd c:\MyFlutterProjects\sportsense-ai\sportsense; & .\.venv\Scripts\Activate.ps1; Start-Job -ScriptBlock { Set-Location "c:\MyFlutterProjects\sportsense-ai\sportsense"; & .\.venv\Scripts\python.exe scripts/uefa_parser_api.py } -Name "UEFA_API"; Start-Sleep -Seconds 5; Start-Job -ScriptBlock { Set-Location "c:\MyFlutterProjects\sportsense-ai\sportsense"; & .\.venv\Scripts\python.exe scripts/qwen_api.py } -Name "Qwen_API" 2>$null; flutter emulators --launch Small_Phone; Start-Sleep -Seconds 30; $devicesOutput = flutter devices 2>&1 | Out-String; if ($devicesOutput -match "emulator-(\d+)") { $emulatorId = "emulator-" + $matches[1]; flutter run --device-id $emulatorId } else { Write-Host "Эмулятор не запустился" }
```

**ИЛИ ИСПОЛЬЗУЙТЕ ГОТОВЫЙ СКРИПТ:**

```bash
# В PowerShell выполните:
.\run_sportsense.ps1
```

### Что происходит при запуске:

1. **🐍 Активация Python venv**
2. **⚽ UEFA Parser API** (порт 5001) - парсит рейтинги UEFA через Playwright
3. **🤖 Qwen AI API** (порт 5000) - локальный AI чат (опционально)
4. **📱 Small Phone эмулятор** - Android эмулятор 480x800 пикселей
5. **🎯 Flutter приложение** - Sportsense AI устанавливается и запускается на эмуляторе

### Ручной запуск по шагам:

```bash
# 1. Активировать Python
& .\.venv\Scripts\Activate.ps1

# 2. Запустить UEFA API (в отдельном терминале)
python scripts/uefa_parser_api.py

# 3. Запустить Qwen API (опционально)
python scripts/qwen_api.py

# 4. Запустить Small Phone эмулятор
flutter emulators --launch Small_Phone

# 5. Подождать 30 секунд и запустить приложение
Start-Sleep -Seconds 30
flutter devices  # найти ID эмулятора
flutter run --device-id emulator-XXXX
```

### Проверка работы API:

```bash
# UEFA API
curl http://127.0.0.1:5001/health

# Qwen API (если запущен)
curl http://127.0.0.1:5000/health
```

### Troubleshooting:

- **Эмулятор не запускается**: `flutter doctor` - проверить Android SDK
- **API не доступны**: Проверить порты 5000/5001, перезапустить
- **Qwen не грузится**: Модель большая, пропустить или подождать
- **Flutter ошибки**: `flutter clean && flutter pub get`
- **Код не компилируется**: Проверить исправления в `local_vector_db.dart`

### Small Phone спецификации:

- **Разрешение**: 480x800 пикселей (компактный телефон)
- **Android API**: 27+
- **Особенности**: Идеален для тестирования UI на маленьком экране

### 🔧 Исправления для mobile:

Проект был адаптирован для работы на мобильных устройствах:
- Заменен `dart:html` на `shared_preferences`
- Добавлена зависимость `shared_preferences: ^2.2.2`

Приложение автоматически подключается к локальным API на `127.0.0.1`.