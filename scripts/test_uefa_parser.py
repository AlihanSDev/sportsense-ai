#!/usr/bin/env python3
"""
Тестовый скрипт для проверки парсинга UEFA Rankings.
Использует Playwright для рендеринга JavaScript.

Запуск:
    python scripts/test_uefa_parser.py

Установка зависимостей:
    pip install playwright
    playwright install
"""

import sys
import time
from datetime import datetime

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("❌ Playwright не установлен!")
    print("Установите командой:")
    print("  pip install playwright")
    print("  playwright install")
    sys.exit(1)


def parse_uefa_rankings():
    """
    Парсит рейтинг клубов UEFA с официального сайта через браузер.
    
    Returns:
        Список словарей с данными рейтинга.
    """
    url = "https://www.uefa.com/nationalassociations/uefarankings/club/"
    
    rankings = []
    
    print(f"🔗 URL: {url}")
    print(f"🌐 Запуск браузера...")
    
    with sync_playwright() as p:
        # Запуск браузера
        browser = p.chromium.launch(headless=True, args=[
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
        ])
        
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080},
        )
        
        page = context.new_page()
        
        print(f"📡 Загрузка страницы...")
        start_time = time.time()
        
        try:
            page.goto(url, wait_until="networkidle", timeout=60000)
            
            # Ждём загрузки AG-Grid таблицы
            print("⏳ Ожидание загрузки таблицы...")
            page.wait_for_selector('div.ag-center-cols-container', timeout=30000)
            
            # Дополнительная задержка для рендеринга данных
            time.sleep(5)
            
            load_time = time.time() - start_time
            print(f"✅ Страница загружена за {load_time:.2f} сек")
            
            # Получаем HTML контент
            content = page.content()
            print(f"📦 Размер HTML: {len(content):,} байт")
            
            # Ищем строки таблицы
            rows = page.query_selector_all('div[role="row"]')
            print(f"🔍 Найдено строк с role='row': {len(rows)}")
            
            # Поиск в ag-center-cols-container
            grid_container = page.query_selector('div.ag-center-cols-container')
            if grid_container:
                print("🔍 Найден ag-center-cols-container")
                container_rows = grid_container.query_selector_all('div[role="row"]')
                print(f"   Найдено строк в контейнере: {len(container_rows)}")
                rows = container_rows
            
            # Извлечение данных из строк
            for i, row in enumerate(rows):
                row_data = {}
                
                # Извлекаем ячейки с col-id
                cells = row.query_selector_all('div[role="gridcell"]')
                
                for cell in cells:
                    col_id = cell.get_attribute('col-id')
                    if not col_id:
                        continue
                    
                    # Ищем значение в span.ag-cell-value
                    value_span = cell.query_selector('span.ag-cell-value')
                    if value_span:
                        value = value_span.text_content().strip()
                    else:
                        value = cell.text_content().strip()
                    
                    if value:
                        row_data[col_id] = value
                
                if row_data and len(row_data) >= 2:
                    rankings.append(row_data)
            
            print(f"\n📊 Найдено записей: {len(rankings)}")
            
        except Exception as e:
            print(f"❌ Ошибка: {e}")
        
        finally:
            browser.close()
    
    return rankings


def print_rankings(rankings):
    """
    Выводит рейтинг в красивом формате.
    """
    if not rankings:
        print("\n❌ Данные не найдены!")
        print("\nВозможные причины:")
        print("   • Сайт блокирует автоматизированный доступ")
        print("   • Требуется больше времени на загрузку")
        print("   • Изменилась структура сайта UEFA")
        return
    
    print("\n" + "=" * 100)
    print("UEFA CLUB RANKINGS")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 100)
    
    # Определяем заголовки из первой записи
    if rankings:
        first_row = rankings[0]
        headers = list(first_row.keys())
        
        # Форматируем заголовки
        header_map = {
            'association': 'Страна',
            'clubs': 'Клубы',
            'bonus': 'Бонус',
            'points': 'Очки',
            'avg': 'Среднее',
            'rank': 'Место',
        }
        
        # Печать заголовков
        print(f"{'№':<4}", end="")
        for h in headers:
            display_name = header_map.get(h, h.title())
            print(f"{display_name:<20}", end="")
        print()
        
        print("-" * 100)
        
        # Печать данных
        for i, row in enumerate(rankings, 1):
            print(f"{i:<4}", end="")
            for h in headers:
                value = row.get(h, '')
                print(f"{value:<20}", end="")
            print()
        
        print("=" * 100)
        print(f"Всего записей: {len(rankings)}")
        print("=" * 100)


def main():
    """Точка входа скрипта."""
    print("=" * 100)
    print("🏆 UEFA Rankings Parser Test (Playwright)")
    print("=" * 100)
    print()
    
    # Парсинг
    rankings = parse_uefa_rankings()
    
    # Вывод результатов
    print_rankings(rankings)
    
    # Проверка успешности
    if rankings:
        print("\n✅ Парсинг успешен!")
        print(f"   Получено {len(rankings)} записей")
        
        # Показываем первую запись подробно
        if rankings:
            print("\n📋 Пример первой записи:")
            for key, value in rankings[0].items():
                print(f"   {key}: {value}")
    else:
        print("\n⚠️ Парсинг не удался")
    
    print()
    print("=" * 100)


if __name__ == "__main__":
    main()
