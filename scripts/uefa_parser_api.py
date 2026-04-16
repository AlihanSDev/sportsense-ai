#!/usr/bin/env python3
"""
API сервер для парсинга UEFA Rankings.
Использует Playwright для рендеринга JavaScript.

Запуск:
    python scripts/uefa_parser_api.py

Установка зависимостей:
    pip install playwright flask flask-cors
    playwright install
"""

import sys
import time
from datetime import datetime
from flask import Flask, jsonify
from flask_cors import CORS

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("ERROR: Playwright not installed!")
    print("Install with: pip install playwright && playwright install")
    sys.exit(1)

app = Flask(__name__)
CORS(app)

# Кэш для данных
_rankings_cache = None
_cache_timestamp = None
_CACHE_TTL = 3600  # 1 час

# Конфигурация сервера
HOST = "0.0.0.0"  # Listen on all interfaces for emulator access
PORT = 5001


def parse_uefa_rankings():
    """Парсит рейтинг клубов UEFA через браузер."""
    url = "https://www.uefa.com/nationalassociations/uefarankings/club/"
    
    rankings = []
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=[
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
        ])
        
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080},
        )
        
        page = context.new_page()
        
        try:
            print(f"Loading page: {url}")
            page.goto(url, wait_until="networkidle", timeout=60000)
            
            print("Waiting for table to load...")
            # Wait for table container to appear
            page.wait_for_selector('div.ag-center-cols-container', timeout=30000)
            
            # Additional delay for data rendering
            print("Waiting for data rendering...")
            time.sleep(5)
            
            # Get page content
            content = page.content()
            print(f"HTML size: {len(content)} bytes")
            
            # Find table rows
            rows = page.query_selector_all('div[role="row"]')
            print(f"Found rows with role='row': {len(rows)}")
            
            # Alternatively: search in container
            grid_container = page.query_selector('div.ag-center-cols-container')
            if grid_container:
                print("Found ag-center-cols-container")
                container_rows = grid_container.query_selector_all('div[role="row"]')
                print(f"   Found rows in container: {len(container_rows)}")
                if len(container_rows) > len(rows):
                    rows = container_rows
            
            # If still no rows, try different selector
            if len(rows) == 0:
                print("No rows found, trying alternative search...")
                rows = page.query_selector_all('div.ag-row')
                print(f"   Found rows with ag-row: {len(rows)}")
            
            print(f"\nExtracting data from {len(rows)} rows...")
            
            for i, row in enumerate(rows):
                row_data = {}
                cells = row.query_selector_all('div[role="gridcell"]')
                
                for cell in cells:
                    col_id = cell.get_attribute('col-id')
                    if not col_id:
                        continue
                    
                    value_span = cell.query_selector('span.ag-cell-value')
                    value = value_span.text_content().strip() if value_span else cell.text_content().strip()
                    
                    if value:
                        row_data[col_id] = value
                
                # Если не нашли association, пробуем найти в первом столбце
                if 'association' not in row_data and len(cells) > 0:
                    # Первый столбец обычно содержит название страны
                    first_cell = cells[0]
                    first_value = first_cell.text_content().strip()
                    if first_value and first_value != row_data.get('clubs', ''):
                        row_data['association'] = first_value
                
                # Добавляем только если есть данные
                if row_data and len(row_data) >= 2:
                    # Добавляем rank на основе позиции
                    row_data['rank'] = str(i + 1)
                    rankings.append(row_data)
                    association = row_data.get('association', row_data.get('col_0', 'Unknown'))
                    points = row_data.get('points', row_data.get('col_3', 'N/A'))
                    print(f"   [OK] Row {i+1}: {association} (points: {points})")
            
            print(f"\nTotal extracted {len(rankings)} records")

        except Exception as e:
            print(f"Parsing error: {e}")
            import traceback
            traceback.print_exc()
        finally:
            browser.close()
    
    return rankings


@app.route('/health', methods=['GET'])
def health():
    """Проверка доступности."""
    return jsonify({
        'status': 'ok',
        'service': 'UEFA Parser API',
        'cached': _rankings_cache is not None,
        'cache_timestamp': _cache_timestamp.isoformat() if _cache_timestamp else None
    })


@app.route('/rankings', methods=['GET'])
def get_rankings():
    """Получение данных рейтинга."""
    global _rankings_cache, _cache_timestamp
    
    # Check cache
    if _rankings_cache is not None and _cache_timestamp is not None:
        age = (datetime.now() - _cache_timestamp).total_seconds()
        if age < _CACHE_TTL:
            print(f"Returning from cache (age: {age:.0f} sec)")
            return jsonify({
                'status': 'ok',
                'source': 'cache',
                'data': _rankings_cache,
                'count': len(_rankings_cache),
                'timestamp': _cache_timestamp.isoformat()
            })

    # Parse fresh
    print("Parsing UEFA Rankings...")
    rankings = parse_uefa_rankings()
    
    if rankings:
        _rankings_cache = rankings
        _cache_timestamp = datetime.now()
        print(f"Found {len(rankings)} records")
        
        return jsonify({
            'status': 'ok',
            'source': 'live',
            'data': rankings,
            'count': len(rankings),
            'timestamp': _cache_timestamp.isoformat()
        })
    else:
        return jsonify({
            'status': 'error',
            'message': 'No data found',
            'data': [],
            'count': 0
        }), 404


@app.route('/rankings/fresh', methods=['GET'])
def get_fresh_rankings():
    """Получение свежих данных (без кэша)."""
    global _rankings_cache, _cache_timestamp
    
    print(">>> Force parsing UEFA Rankings...")
    rankings = parse_uefa_rankings()
    
    if rankings:
        _rankings_cache = rankings
        _cache_timestamp = datetime.now()
        print(f"[SUCCESS] Found {len(rankings)} records")
        
        return jsonify({
            'status': 'ok',
            'source': 'fresh',
            'data': rankings,
            'count': len(rankings),
            'timestamp': _cache_timestamp.isoformat()
        })
    else:
        return jsonify({
            'status': 'error',
            'message': 'No data found',
            'data': [],
            'count': 0
        }), 404


if __name__ == '__main__':
    print("=" * 60)
    print("UEFA Rankings Parser API Server")
    print("=" * 60)
    print()
    print("Starting on http://127.0.0.1:5001")
    print("Endpoints:")
    print("  GET /health     - health check")
    print("  GET /rankings   - get data (with cache)")
    print("  GET /rankings/fresh - get fresh data")
    print()
    print("Press Ctrl+C to stop")
    print("=" * 60)
    
    app.run(host=HOST, port=PORT, debug=False)
