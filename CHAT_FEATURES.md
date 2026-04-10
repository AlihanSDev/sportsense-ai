# Новые функции чат-бота Sportsense

## 🎯 Реализованные возможности

### 1. Персональные векторные базы для каждого чата
Каждый чат теперь имеет свою собственную векторную базу данных для:
- Хранения эмбеддингов сообщений
- Суммаризации истории чата
- Контекстного поиска (RAG)

**Файлы:**
- `lib/services/chat_vector_db_manager.dart` - менеджер персональных ВБД

### 2. Автоматическая генерация названий чатов
Название чата генерируется автоматически на основе первого вопроса пользователя.

**Примеры:**
- Вопрос про футбол → "💬 Вопрос про футбол"
- Вопрос про здоровье → "💬 Вопрос про здоровье"
- Вопрос про технологии → "💬 Вопрос про технологии"

**Поддерживаемые темы:**
- Футбол, баскетбол, хоккей, теннис, бокс
- Формула 1, UEFA
- Здоровье, технологии, еда, путешествия
- Музыка, кино, наука, история
- Экономика, политика, образование

**Файлы:**
- `lib/services/chat_tag_generator.dart` - генератор тегов/названий

### 3. Скрипты для загрузки AI моделей

#### Модель для генерации тегов (Qwen2.5-0.5B)
```bash
python scripts/download_tag_model.py
```

**Характеристики:**
- Размер: ~400 MB
- RAM: ~1 GB
- Квантование: Q4_K_M (4-битное)
- Назначение: Генерация кратких названий чатов

#### Модель эмбеддингов (granite-embedding-278m)
```bash
python scripts/download_embeddings.py
```

**Характеристики:**
- Размер: ~550 MB
- RAM: ~1 GB
- Размерность: 768
- Назначение: Векторизация текстов

#### Основная LLM (Qwen2.5-1.5B)
```bash
python scripts/download_qwen.py
```

**Характеристики:**
- Размер: ~1.7 GB
- RAM: ~2-3 GB
- Квантование: Q8_0 (8-битное)
- Назначение: Генерация ответов

## 🚀 Использование

### Создание нового чата
1. Нажмите "Новый чат" в боковом меню
2. Напишите первый вопрос
3. Название чата сгенерируется автоматически

### Переключение между чатами
1. Откройте боковое меню (иконка ☰)
2. Выберите нужный чат из списка
3. История сообщений загрузится автоматически

### Персональный контекст (RAG)
Каждый чат использует свою историю для:
- Поиска релевантных сообщений
- Генерации контекста для LLM
- Улучшения качества ответов

## 📁 Структура данных

### Векторные базы чатов
```
chat_{chatId}/
├── collection: сообщения чата
├── vector_size: 768
└── distance: Cosine
```

### Метаданные сообщений
```json
{
  "chat_id": "unique_chat_id",
  "message_id": 123,
  "text": "текст сообщения",
  "is_user": true/false,
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## 🔧 Конфигурация

### URL API (main.dart)
```dart
const String QWEN_API_URL = 'http://127.0.0.1:5000';
```

### Параметры генерации тегов
```dart
'max_tokens': 50,
'temperature': 0.3,
'top_p': 0.9,
```

## 📊 Статистика

### Просмотр статистики чата
```dart
final stats = chatVectorDbManager.getChatStats(chatId);
// {
//   'chat_id': 'abc123',
//   'collection_name': 'chat_abc123',
//   'message_count': 42
// }
```

### Общая статистика
```dart
final overallStats = chatVectorDbManager.overallStats;
// {
//   'total_chats': 5,
//   'chat_ids': ['chat1', 'chat2', ...],
//   'global_db_stats': {...}
// }
```

## 🛠 API сервисов

### ChatTagGenerator
```dart
// Генерация названия чата
final title = await tagGenerator.generateChatTitle("Как дела?");

// Генерация сводки для векторизации
final summary = tagGenerator.generateChatSummary(messages);
```

### ChatVectorDbManager
```dart
// Инициализация ВБД чата
await chatVectorDbManager.initializeChatVectorDb(chatId);

// Добавление сообщения
await chatVectorDbManager.addMessage(
  chatId: chatId,
  messageId: 1,
  text: "Привет!",
  isUser: true,
);

// Поиск релевантных сообщений
final results = await chatVectorDbManager.searchRelevantMessages(
  chatId: chatId,
  query: "футбол",
  limit: 5,
);

// Генерация RAG контекста
final context = await chatVectorDbManager.generateRagContext(
  chatId: chatId,
  query: "Кто выиграл матч?",
  limit: 5,
);
```

## 🔄 Интеграция с основным приложением

### Инициализация (main.dart)
```dart
// Генератор тегов
_tagGenerator = ChatTagGenerator(apiBaseUrl: QWEN_API_URL);

// Менеджер ВБД чатов
_chatVectorDbManager = ChatVectorDbManager(
  globalDb: widget.vectorDbManager.localDb,
  vectorizer: widget.queryVectorizer,
);
```

### При отправке сообщения
1. Сообщение сохраняется в SQLite
2. Добавляется в векторную базу чата
3. Генерируется ответ с учетом контекста

## 📝 Примечания

- Векторные базы хранятся в памяти (web) или на диске (mobile)
- При удалении чата удаляется и его векторная база
- LLM API должен быть запущен отдельно: `python scripts/qwen_api.py`
- Для работы эмбеддингов требуется Python скрипт

## 🐛 Отладка

### Проверка инициализации
```dart
print(chatVectorDbManager.overallStats);
```

### Очистка данных
```dart
await chatVectorDbManager.clearChatVectorDb(chatId);
```

### Логи
Все операции логируются в консоль с префиксами:
- ✓ - успех
- ❌ - ошибка
- ⚠️ - предупреждение