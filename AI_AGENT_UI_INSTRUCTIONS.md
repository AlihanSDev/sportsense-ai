# 📘 ИНСТРУКЦИЯ ДЛЯ ИИ-АГЕНТА ПО UI-РАЗРАБОТКЕ

## ⚠️ КРИТИЧЕСКИ ВАЖНО: Разделение ответственности

Этот проект имеет **чёткое разделение** на Frontend (UI) и Backend (бизнес-логика).  
**НЕПРАВИЛЬНЫЕ ИЗМЕНЕНИЯ ПРИВЕДУТ К КОНФЛИКТАМ GIT!**

---

## 📊 АРХИТЕКТУРА ПРОЕКТА

```
sportsense/
├── lib/
│   ├── main.dart                    # ⚠️ ЧАСТИЧНО: UI + инициализация сервисов
│   ├── services/                    # 🔴 ЗАПРЕТНАЯ ЗОНА (Backend)
│   │   ├── qdrant_service.dart      #    Векторная БД (Qdrant)
│   │   ├── qwen_api_service.dart    #    AI API (Qwen)
│   │   ├── uefa_parser.dart         #    Парсер UEFA
│   │   ├── vector_db_manager.dart   #    Менеджер векторных БД
│   │   └── ... (ещё 8 файлов)
│   │
│   └── widgets/                     # ✅ ТВОЯ ЗОНА (Frontend)
│       ├── chat_interface.dart      #    Чат-интерфейс
│       ├── space_background.dart    #    Фон (космос)
│       └── uefa_search_indicator.dart # Индикатор поиска
│
├── scripts/                         # 🔴 ЗАПРЕТНАЯ ЗОНА (Backend Python)
│   ├── qwen_api.py                  #    Python API для Qwen
│   ├── uefa_parser_api.py           #    Python парсер с Playwright
│   ├── embed_chunks.py              #    Эмбеддинги
│   └── ...
│
├── pubspec.yaml                     # ⚠️ ТОЛЬКО ПО СОГЛАСОВАНИЮ
├── .gitignore                       # ⚠️ РЕДКО МЕНЯЕТСЯ
└── assets/                          # ✅ МОЖНО ДОБАВЛЯТЬ
```

---

## 🎯 ЗОНЫ ОТВЕТСТВЕННОСТИ

### ✅ ТВОЯ ЗОНА (Frontend / UI)

**Можно изменять БЕЗ согласования:**

| Файл | Что можно менять |
|------|------------------|
| `lib/widgets/chat_interface.dart` | Стили пузырей, цвета, анимации, шрифты, размеры, иконки |
| `lib/widgets/space_background.dart` | Цвета фона, анимации звёзд, эффекты |
| `lib/widgets/uefa_search_indicator.dart` | Стили индикатора, цвета, анимации |
| `assets/` | Добавлять изображения, шрифты, данные |

**Можно изменять с осторожностью:**

| Файл | Что можно менять | Что НЕЛЬЗЯ |
|------|------------------|------------|
| `lib/main.dart` | ThemeData, цвета темы, шрифты, виджеты в `build()` | Инициализацию сервисов в `main()`, параметры подключения |

---

### 🔴 ЗАПРЕТНАЯ ЗОНА (Backend)

**НЕЛЬЗЯ изменять БЕЗ согласования с backend-разработчиком:**

| Файл/Директория | Причина |
|-----------------|---------|
| `lib/services/*.dart` | Бизнес-логика, API, парсеры, векторные БД |
| `scripts/*.py` | Python-скрипты, AI модели, парсеры |
| `models/` | ML модели |
| `data/` | Данные векторной БД |
| `pubspec.yaml` | Зависимости проекта (конфликты!) |
| `.gitignore` | Правила игнорирования |
| `.env`, `.env.example` | Переменные окружения |

---

## 📁 ДЕТАЛЬНОЕ ОПИСАНИЕ UI-ФАЙЛОВ

### 1. `lib/widgets/chat_interface.dart`

**Назначение:** Основной чат-интерфейс (пузыри сообщений, поле ввода, анимации)

**Структура:**
```dart
class ChatMessage          // Модель сообщения
class ChatInterface        // Главный виджет чата
class _ChatInterfaceState  // Состояние и логика
```

**Что можно менять:**

✅ **Цвета:**
```dart
// Градиенты иконок
LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)])

// Цвета пузырей сообщений
color: message.isUser 
    ? const Color(0xFF7C4DFF).withOpacity(0.3)  // Пользователь
    : Colors.grey.withOpacity(0.15)              // Бот

// Цвета текста
color: message.isUser 
    ? Colors.white 
    : (message.textColor ?? Colors.grey[200])
```

✅ **Размеры и отступы:**
```dart
padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)
borderRadius: BorderRadius.circular(20)
fontSize: 15
```

✅ **Анимации:**
```dart
AnimatedOpacity(opacity: _fadedIn[index] ? 1.0 : 0.0, duration: 300ms)
TweenAnimationBuilder(duration: 400ms + index * 200ms)
```

✅ **Иконки:**
```dart
Icons.smart_toy_outlined  // Для бота
Icons.person_outline      // Для пользователя
Icons.send_rounded        // Кнопка отправки
Icons.attach_file         // Вложения
```

**Что НЕЛЬЗЯ менять:**

❌ **Сигнатуры методов:**
```dart
// НЕЛЬЗЯ: менять параметры
ChatMessage({required this.text, required this.isUser, ...})

// НЕЛЬЗЯ: менять тип возвращаемого значения
Future<void> _startTyping(String fullText) async
```

❌ **Логику работы:**
```dart
// НЕЛЬЗЯ: удалять обработку сообщений
if (widget.messages.length > oldWidget.messages.length) {
    final newMsg = widget.messages.last;
    _displayedTexts.add(newMsg.text);
}
```

❌ **Взаимодействие с сервисами:**
```dart
// НЕЛЬЗЯ: добавлять вызовы сервисов
widget.onSendMessage(text)  // Это ок, это callback
```

---

### 2. `lib/widgets/space_background.dart`

**Назначение:** Анимированный фон с космической тематикой

**Структура:**
```dart
class SpaceBackground        // Главный виджет
class _SpaceBackgroundState  // Состояние с анимациями
class Star                   // Модель звезды
class StarFieldPainter       // Рисовальщик звёзд
class NebulaPainter          // Рисовальщик туманностей
```

**Что можно менять:**

✅ **Цвета фона:**
```dart
// Градиент фона
colors: [
    Color(0xFF000000),  // Чёрный
    Color(0xFF0A0A0F),  // Тёмно-синий
    Color(0xFF0F0F1A),  // Светлее
]
```

✅ **Цвета туманностей:**
```dart
Color(0xFF7C4DFF).withOpacity(0.15)  // Фиолетовый
Color(0xFF00D4FF).withOpacity(0.1)   // Голубой
Color(0xFFE040FB).withOpacity(0.08)  // Розовый
```

✅ **Параметры анимации:**
```dart
duration: const Duration(seconds: 3)   // Скорость мерцания
duration: const Duration(seconds: 20)  // Скорость облаков
```

✅ **Количество и размер звёзд:**
```dart
List.generate(100, (_) => Star())  // 100 звёзд
size: math.Random().nextDouble() * 2 + 0.5
```

**Что НЕЛЬЗЯ менять:**

❌ **Алгоритм рисования:**
```dart
// НЕЛЬЗЯ: ломать CustomPainter
void paint(Canvas canvas, Size size) {
    // Сложная логика рисования
}
```

---

### 3. `lib/widgets/uefa_search_indicator.dart`

**Назначение:** Индикатор поиска "Поиск актуальной информации..."

**Структура:**
```dart
class UefaSearchIndicator      // Виджет индикатора
class _UefaSearchIndicatorState // Анимация пульсации
class UefaErrorIndicator       // Виджет ошибки
```

**Что можно менять:**

✅ **Цвета:**
```dart
// Можно заменить на конкретные цвета вместо Theme.of(context)
colors: [
    Color(0xFF6EC6FF).withOpacity(0.2),
    Color(0xFF4A90E2).withOpacity(0.2),
]
```

✅ **Размеры и отступы:**
```dart
padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
borderRadius: BorderRadius.circular(20)
```

✅ **Анимацию:**
```dart
duration: const Duration(milliseconds: 1500)  // Скорость пульсации
Tween<double>(begin: 0.8, end: 1.0)           // Диапазон пульсации
```

**Что НЕЛЬЗЯ менять:**

❌ **Сигнатуры виджетов:**
```dart
// НЕЛЬЗЯ: убирать параметры
UefaSearchIndicator({this.message = 'Поиск информации...'})
```

---

### 4. `lib/main.dart`

**Назначение:** Точка входа приложения + UI главного экрана

**Нововведение:** Добавлено боковое меню (Drawer) с историей чата, открывается
по кнопке «гамбургер» в левом верхнем углу. Это всё ещё часть фронтенда,
можно менять стили и содержимое.

**Структура:**
```dart
void main() async              // ⚠️ Инициализация сервисов (НЕ ТРОГАТЬ)
class SpaceApp                 // ✅ UI тема (МОЖНО МЕНЯТЬ)
class HomePage                 // ⚠️ Частично (только build())
class _HomePageState           // ⚠️ Осторожно
```

**Что можно менять:**

✅ **Тему приложения:**
```dart
theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C4DFF),  // ✅ Можно
        brightness: Brightness.dark,          // ✅ Можно
        background: const Color(0xFFF8F9FA),  // ✅ Можно
    ),
    textTheme: GoogleFonts.poppinsTextTheme(...),  // ✅ Можно
    scaffoldBackgroundColor: ...  // ✅ Можно
)
```

✅ **Виджеты в `build()`:**
```dart
// ✅ Можно менять стили, цвета, размеры
ShaderMask(
    shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)],
    ),
    child: const Text(
        'Sportsense',
        style: TextStyle(
            fontSize: 42,           // ✅ Можно
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [...],         // ✅ Можно
        ),
    ),
)
```

**Что НЕЛЬЗЯ менять:**

❌ **Инициализацию сервисов в `main()`:**
```dart
// ❌ НЕЛЬЗЯ: удалять или менять
final vectorDbManager = VectorDatabaseManager();
await vectorDbManager.initialize();

final queryVectorizer = UserQueryVectorizerService(...);
await queryVectorizer.initialize();

final uefaParser = UefaParser(...);
final qwenApi = QwenApiService();
```

❌ **Передачу параметров в виджеты:**
```dart
// ❌ НЕЛЬЗЯ: удалять параметры
runApp(SpaceApp(
    vectorDbManager: vectorDbManager,  // Обязательно
    queryVectorizer: queryVectorizer,  // Обязательно
    uefaParser: uefaParser,            // Обязательно
    ...
))
```

❌ **Логику обработки сообщений:**
```dart
// ❌ НЕЛЬЗЯ: ломать RAG пайплайн
Future<void> _sendMessage(String text) async {
    // Проверка релевантности
    final relevance = RankingsRelevanceService.checkRelevance(text);
    
    // Парсинг
    await _uefaParser.parseAndSaveRankings();
    
    // Поиск в векторной базе
    ragContext = await _rankingsSearch.getRagContext(text, limit: 10);
    
    // Запрос к Qwen API
    final qwenResponse = await _qwenApi.chat(text, context: ragContext);
}
```

---

## 🚀 РАБОЧИЙ ПРОЦЕСС

### 1. Перед началом работы

```bash
# Убедись, что ты на правильной ветке
git checkout feature/ui-visual-clean

# Загрузи актуальные изменения
git fetch origin
git pull origin main
```

### 2. Внесение изменений

```bash
# Проверь, что изменяешь только UI-файлы
git status

# Добавь изменения
git add lib/widgets/
git add lib/main.dart  # Только если меняешь UI

# Закоммить с понятным сообщением
git commit -m "feat(ui): обновить цвета чата на сине-голубые"
```

### 3. Проверка перед пушем

```bash
# Убедись, что НЕ изменяешь сервисы
git diff --stat main lib/services/  # Должно быть пусто
git diff --stat main scripts/       # Должно быть пусто
git diff --stat main pubspec.yaml   # Должно быть пусто

# Проверь, что изменяешь только UI
git diff --stat main lib/widgets/   # Должны быть изменения
```

### 4. Пуш изменений

```bash
git push origin feature/ui-visual-clean
```

---

## ⚠️ ЗОНЫ КОНФЛИКТОВ

### Высокий риск 🔴

| Файл | Почему | Решение |
|------|--------|---------|
| `pubspec.yaml` | Backend добавляет Python зависимости, UI добавляет Flutter пакеты | Координировать изменения |
| `lib/main.dart` | Backend меняет инициализацию, UI меняет тему | Разделять изменения |

### Средний риск 🟡

| Файл | Почему | Решение |
|------|--------|---------|
| `lib/services/` | Только backend | Не трогать |
| `.gitignore` | Оба могут добавлять правила | Редко менять |

### Низкий риск 🟢

| Файл | Почему | Решение |
|------|--------|---------|
| `lib/widgets/` | Только UI | Безопасно |
| `assets/` | Только UI | Безопасно |

---

## 🛡️ ПРАВИЛА БЕЗОПАСНОСТИ

### ✅ МОЖНО:

1. **Менять цвета, шрифты, размеры** в UI-файлах
2. **Добавлять новые виджеты** в `lib/widgets/`
3. **Менять анимации** и эффекты
4. **Добавлять assets** (изображения, шрифты)
5. **Менять тему** в `lib/main.dart`

### ❌ НЕЛЬЗЯ:

1. **Изменять `lib/services/*.dart`** без согласования
2. **Изменять `scripts/*.py`** без согласования
3. **Добавлять зависимости** в `pubspec.yaml` без согласования
4. **Менять инициализацию сервисов** в `main()`
5. **Ломать существующие API** виджетов

---

## 🔍 ЧЕК-ЛИСТ ПЕРЕД КОММИТОМ

Перед каждым коммитом проверь:

- [ ] Я изменил только файлы из **зелёной зоны** (`lib/widgets/`, `assets/`)?
- [ ] Я НЕ трогал `lib/services/`?
- [ ] Я НЕ трогал `scripts/`?
- [ ] Я НЕ трогал `pubspec.yaml`?
- [ ] Моё сообщение коммита начинается с `feat(ui):` или `style(ui):`?
- [ ] Я на ветке `feature/ui-visual-clean`?

**Если хотя бы один ответ "НЕТ" — остановись и проверь изменения!**

---

## 📝 ПРИМЕРЫ ПРАВИЛЬНЫХ КОММИТОВ

```bash
# Изменение цветов
git commit -m "feat(ui): сменить цветовую схему на сине-голубую"

# Новая анимация
git commit -m "feat(ui): добавить плавное появление сообщений"

# Новый виджет
git commit -m "feat(ui): добавить виджет приветствия"

# Исправление стилей
git commit -m "style(ui): увеличить отступы в чате"

# Новый фон
git commit -m "feat(ui): добавить анимированный фон с сотами"
```

---

## 📝 ПРИМЕРЫ НЕПРАВИЛЬНЫХ КОММИТОВ

```bash
# ❌ Изменение сервиса
git commit -m "fix: исправить ошибку в QdrantService"

# ❌ Изменение Python-скрипта
git commit -m "feat: добавить новый парсер"

# ❌ Изменение зависимостей
git commit -m "chore: добавить пакет animated_text_kit"

# ❌ Без префикса
git commit -m "обновить цвета"
```

---

## 🆘 ЕСЛИ СЛУЧИЛСЯ КОНФЛИКТ

### Сценарий 1: Конфликт при merge с main

```bash
# 1. Отмени слияние
git merge --abort

# 2. Загрузи актуальный main
git fetch origin
git checkout main
git pull origin main

# 3. Вернись на свою ветку
git checkout feature/ui-visual-clean

# 4. Попробуй аккуратно влить изменения
git merge main

# 5. Если конфликт — открой файлы и выбери изменения
#    <<<<<<< HEAD
#    Твои UI изменения
#    =======
#    Изменения backend
#    >>>>>>> main

# 6. Оставь ОБА изменения (если они не пересекаются)
# 7. Закоммить результат
git add <файлы>
git commit -m "Merge conflict resolved"
```

### Сценарий 2: Случайно изменил сервис

```bash
# 1. Посмотри изменения
git diff lib/services/qdrant_service.dart

# 2. Отмени изменения в конкретном файле
git checkout HEAD -- lib/services/qdrant_service.dart

# 3. Или отмени все изменения
git reset --hard HEAD
```

---

## 📊 ТЕКУЩАЯ ВЕТКА

**Ветка:** `feature/ui-visual-clean`  
**Основана на:** `main` (коммит `1cc095f`)  
**Статус:** Чистая, готова к работе

---

## 🎨 ТЕКУЩАЯ ТЕМА (в main)

```dart
// Тёмная тема
brightness: Brightness.dark

// Фиолетово-розовые цвета
seedColor: const Color(0xFF7C4DFF)

// Градиенты
colors: [
    Color(0xFF00D4FF),  // Голубой
    Color(0xFF7C4DFF),  // Фиолетовый
    Color(0xFFE040FB),  // Розовый
]
```

---

## 📞 КОГДА ОБРАЩАТЬСЯ К BACKEND-РАЗРАБОТЧИКУ

Обращайся, если нужно:

1. **Добавить новую зависимость** в `pubspec.yaml`
2. **Изменить API сервиса** (например, добавить параметр в метод)
3. **Изменить инициализацию** в `main()`
4. **Добавить новый Python-скрипт**
5. **Изменить `.gitignore`**
6. **Сделать merge в main**

---

## 📚 ДОПОЛНИТЕЛЬНЫЕ РЕСУРСЫ

- [Flutter Material Design](https://material.io/develop/flutter)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)

---

**Создано:** 2026-03-12  
**Версия:** 1.0  
**Для:** ИИ-агента по UI-разработке

---

## 🎯 ГЛАВНОЕ ПРАВИЛО

> **Если не уверен — СПРОСИ! Лучше переспросить, чем создать конфликт.**

**Изменяй только то, что находится в `lib/widgets/` и `assets/`.**  
**Всё остальное — только по согласованию!**
