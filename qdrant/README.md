# Запуск локальной Qdrant

## Вариант 1: Docker (рекомендуется)
```bash
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

## Вариант 2: Docker с сохранением данных
```bash
docker run -p 6333:6333 -p 6334:6334 -v $(pwd)/qdrant_storage:/qdrant/storage qdrant/qdrant
```

## Вариант 3: Локальная установка
Скачайте с https://qdrant.tech/documentation/quickstart/

## Проверка работы
Откройте в браузере: http://localhost:6333

## API Endpoints
- GET  /collections - список коллекций
- PUT  /collections/{name} - создать коллекцию
- GET  /collections/{name} - информация о коллекции
- PUT  /collections/{name}/points - добавить точки
- POST /collections/{name}/points/search - поиск
