# Инструкции по запуску серверов Sportsense AI

## 🚀 Быстрый старт

### 1. Запуск Qwen 1.5B API (основной для чат-бота)

```bash
# Установка зависимостей
pip install llama-cpp-python flask flask-cors

# Запуск сервера
python scripts/qwen_api.py
```

Сервер будет доступен на: http://127.0.0.1:5000

**Endpoints:**
- `GET /health` - проверка доступности
- `POST /chat` - запрос к чат-боту
- `POST /generate` - генерация текста
- `POST /generate_title` - генерация названия чата

### 2. Запуск Qwen 0.5B API (для генерации тегов)

```bash
# Запуск сервера
python scripts/qwen_api_0.5.py
```

Сервер будет доступен на: http://127.0.0.1:5002

### 3. Запуск API Control Panel (GUI)

```bash
# Установка дополнительных зависимостей
pip install psutil

# Запуск панели управления
python scripts/api_control_panel.py
```

**Функции панели:**
- Запуск/остановка серверов
- Выбор модели (1.5B или 0.5B)
- Выбор порта (5000 или 5002)
- Тестирование чата
- Генерация названий чатов
- Тест UEFA парсера

### 4. Запуск UEFA Parser API

```bash
# Установка зависимостей
pip install playwright beautifulsoup4 lxml

# Установка браузеров
playwright install

# Запуск сервера
python scripts/uefa_parser_api.py
```

Сервер будет доступен на: http://127.0.0.1:8000

## 📋 Полный список команд

### Запуск всех серверов через API Control Panel:

```bash
python scripts/api_control_panel.py
```

### Запуск серверов по отдельности:

```bash
# Терминал 1: Qwen 1.5B API
python scripts/qwen_api.py

# Терминал 2: Qwen 0.5B API (опционально)
python scripts/qwen_api_0.5.py

# Терминал 3: UEFA Parser API
python scripts/uefa_parser_api.py
```

## 🔧 Конфигурация

### Переменные окружения:

```bash
# Порт для Qwen API (по умолчанию 5000)
export QWEN_PORT=5000

# Порт для Qwen 0.5B API (по умолчанию 5002)
export QWEN_05_PORT=5002
```

### Проверка статуса серверов:

```bash
# Проверка Qwen API
curl http://127.0.0.1:5000/health

# Проверка Qwen 0.5B API
curl http://127.0.0.1:5002/health

# Проверка UEFA Parser API
curl http://127.0.0.1:8000/health
```

## 🧪 Тестирование

### Тесты для Qwen 0.5B API:

```bash
python scripts/test_qwen_api_0.5.py
```

### Тесты для Qwen 1.5B API:

```bash
python scripts/test_qwen_api.py
```

## 📱 Flutter приложение

### Запуск Flutter приложения:

```bash
# Установка зависимостей
flutter pub get

# Запуск на вебе
flutter run -d chrome

# Запуск на Android
flutter run

# Запуск на iOS
flutter run
```

### Конфигурация API в Flutter:

Файл: `lib/main.dart`

```dart
const String QWEN_API_URL = 'http://127.0.0.1:5000';
const String UEFA_PARSER_API_URL = 'http://127.0.0.1:8000';
```

## 🎯 Генерация названий чатов

### В Flutter приложении:

1. Создайте новый чат
2. Напишите первое сообщение
3. Название чата будет автоматически сгенерировано с помощью Qwen 1.5B API

### Через API:

```bash
curl -X POST http://127.0.0.1:5000/generate_title \
  -H "Content-Type: application/json" \
  -d '{"message": "Расскажи про футбол в Лиге Чемпионов"}'
```

Ответ:
```json
{
  "title": "Футбол в Лиге Чемпионов"
}
```

## 🔍 Диагностика

### Проверка логов:

```bash
# Логи Qwen API
tail -f logs/qwen_api.log

# Логи UEFA Parser
tail -f logs/uefa_parser.log
```

### Остановка всех процессов:

```bash
# Через API Control Panel
# Нажмите кнопку "Остановить все Python процессы"

# Или вручную
taskkill /F /IM python.exe  # Windows
pkill -f python              # Linux/macOS
```

## 📊 Мониторинг

### Проверка использования портов:

```bash
# Windows
netstat -ano | findstr :5000
netstat -ano | findstr :5002
netstat -ano | findstr :8000

# Linux/macOS
lsof -i :5000
lsof -i :5002
lsof -i :8000
```

### Проверка процессов:

```bash
# Windows
tasklist | findstr python

# Linux/macOS
ps aux | grep python
```

## ⚠️ Решение проблем

### Ошибка: "UnicodeEncodeError"

**Решение:** Исправлено в последней версии. Эмодзи заменены на текстовые аналоги.

### Ошибка: "Модель не найдена"

**Решение:** Скачайте модели:

```bash
python scripts/download_qwen.py
```

### Ошибка: "Порт уже используется"

**Решение:** Остановите процесс на порту или используйте другой порт:

```bash
# Найти PID процесса на порту 5000
netstat -ano | findstr :5000

# Остановить процесс
taskkill /F /PID <PID>
```

## 📚 Дополнительная документация

- [QWEN_API.md](scripts/QWEN_API.md) - документация по Qwen API
- [CHAT_FEATURES.md](CHAT_FEATURES.md) - документация по чат-функциям
- [README.md](README.md) - общая документация проекта