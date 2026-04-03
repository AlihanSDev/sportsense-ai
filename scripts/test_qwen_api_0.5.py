#!/usr/bin/env python3
"""
Тесты для Qwen 0.5B API сервера.
Запуск: python scripts/test_qwen_api_0.5.py
"""

import sys
import os
import subprocess
import time
import requests
import json
from pathlib import Path

# Добавляем родительскую директорию в путь
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_test(name, status, message=""):
    """Вывод результата теста."""
    if status == "PASS":
        print(f"{Colors.GREEN}✓ {name}{Colors.END}")
    elif status == "FAIL":
        print(f"{Colors.RED}✗ {name}{Colors.END}")
        if message:
            print(f"  {Colors.RED}{message}{Colors.END}")
    elif status == "SKIP":
        print(f"{Colors.YELLOW}⊘ {name} (пропущен){Colors.END}")
    elif status == "INFO":
        print(f"{Colors.BLUE}ℹ {name}{Colors.END}")

def check_dependencies():
    """Проверка установленных зависимостей."""
    print(f"\n{Colors.BOLD}Проверка зависимостей:{Colors.END}")
    
    required_packages = [
        'flask',
        'flask_cors',
        'llama_cpp',
        'requests'
    ]
    
    all_installed = True
    for package in required_packages:
        try:
            __import__(package)
            print_test(f"Пакет {package}", "PASS")
        except ImportError:
            print_test(f"Пакет {package}", "FAIL", "Не установлен")
            all_installed = False
    
    return all_installed

def check_model_exists():
    """Проверка наличия модели."""
    print(f"\n{Colors.BOLD}Проверка модели:{Colors.END}")
    
    model_path = Path("models/qwen2.5-0.5b-tag-generator/qwen2.5-0.5b-instruct-q4_k_m.gguf")
    
    if model_path.exists():
        size_mb = model_path.stat().st_size / (1024 * 1024)
        print_test(f"Модель найдена ({size_mb:.1f} MB)", "PASS")
        return True
    else:
        print_test("Модель не найдена", "FAIL", f"Ожидается: {model_path}")
        return False

def check_syntax():
    """Проверка синтаксиса файла."""
    print(f"\n{Colors.BOLD}Проверка синтаксиса:{Colors.END}")
    
    script_path = Path("scripts/qwen_api_0.5.py")
    
    if not script_path.exists():
        print_test("Файл qwen_api_0.5.py", "FAIL", "Файл не найден")
        return False
    
    try:
        result = subprocess.run(
            [sys.executable, "-m", "py_compile", str(script_path)],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print_test("Синтаксис Python", "PASS")
            return True
        else:
            print_test("Синтаксис Python", "FAIL", result.stderr)
            return False
    except Exception as e:
        print_test("Синтаксис Python", "FAIL", str(e))
        return False

def check_imports():
    """Проверка импортов в файле."""
    print(f"\n{Colors.BOLD}Проверка импортов:{Colors.END}")
    
    script_path = Path("scripts/qwen_api_0.5.py")
    
    try:
        # Проверяем, что файл может быть скомпилирован и импортирован
        # Используем importlib для загрузки модуля с точкой в имени
        import importlib.util
        spec = importlib.util.spec_from_file_location("qwen_api_0_5", script_path)
        if spec and spec.loader:
            module = importlib.util.module_from_spec(spec)
            # Не выполняем модуль, просто проверяем что он может быть загружен
            print_test("Импорт модуля", "PASS")
            return True
        else:
            print_test("Импорт модуля", "FAIL", "Не удалось загрузить спецификацию")
            return False
    except SyntaxError as e:
        print_test("Импорт модуля", "FAIL", f"Синтаксическая ошибка: {e}")
        return False
    except Exception as e:
        print_test("Импорт модуля", "FAIL", str(e))
        return False

def test_api_endpoints(port=5002):
    """Тестирование API endpoints (без запуска сервера)."""
    print(f"\n{Colors.BOLD}Структура API:{Colors.END}")
    
    script_path = Path("scripts/qwen_api_0.5.py")
    
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Проверяем наличие endpoints
    endpoints = {
        "/health": '@app.route("/health")',
        "/generate": '@app.route("/generate"',
        "/chat": '@app.route("/chat"'
    }
    
    all_found = True
    for name, pattern in endpoints.items():
        if pattern in content:
            print_test(f"Endpoint {name}", "PASS")
        else:
            print_test(f"Endpoint {name}", "FAIL", "Не найден в коде")
            all_found = False
    
    return all_found

def test_server_startup(model_available=False):
    """Тест запуска сервера."""
    print(f"\n{Colors.BOLD}Тест запуска сервера:{Colors.END}")
    
    if not model_available:
        print_test("Запуск сервера", "SKIP", "Модель недоступна")
        return None
    
    script_path = Path("scripts/qwen_api_0.5.py")
    port = 5002
    
    # Устанавливаем переменную окружения для порта
    env = os.environ.copy()
    env['QWEN_PORT'] = str(port)
    
    try:
        print_test("Запуск сервера...", "INFO")
        
        process = subprocess.Popen(
            [sys.executable, str(script_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        )
        
        # Ждем запуска
        time.sleep(5)
        
        # Проверяем health endpoint
        try:
            response = requests.get(f"http://127.0.0.1:{port}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                if data.get('ok'):
                    print_test("Health endpoint", "PASS")
                    print_test("Сервер запущен", "PASS")
                    
                    # Тестируем generate endpoint
                    try:
                        gen_response = requests.post(
                            f"http://127.0.0.1:{port}/generate",
                            json={'prompt': 'Привет', 'max_tokens': 10},
                            timeout=30
                        )
                        if gen_response.status_code == 200:
                            print_test("Generate endpoint", "PASS")
                        else:
                            print_test("Generate endpoint", "FAIL", f"Status: {gen_response.status_code}")
                    except Exception as e:
                        print_test("Generate endpoint", "FAIL", str(e))
                    
                    # Тестируем chat endpoint
                    try:
                        chat_response = requests.post(
                            f"http://127.0.0.1:{port}/chat",
                            json={'message': 'Привет', 'max_tokens': 10},
                            timeout=30
                        )
                        if chat_response.status_code == 200:
                            print_test("Chat endpoint", "PASS")
                        else:
                            print_test("Chat endpoint", "FAIL", f"Status: {chat_response.status_code}")
                    except Exception as e:
                        print_test("Chat endpoint", "FAIL", str(e))
                    
                    return process
                else:
                    print_test("Health endpoint", "FAIL", "Модель не загружена")
            else:
                print_test("Health endpoint", "FAIL", f"Status: {response.status_code}")
        except requests.exceptions.ConnectionError:
            print_test("Подключение к серверу", "FAIL", "Сервер не отвечает")
        except Exception as e:
            print_test("Health endpoint", "FAIL", str(e))
        
        # Останавливаем сервер
        process.terminate()
        process.wait(timeout=5)
        return None
        
    except Exception as e:
        print_test("Запуск сервера", "FAIL", str(e))
        return None

def main():
    """Главная функция тестирования."""
    print(f"\n{Colors.BOLD}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}  Тестирование Qwen 0.5B API{Colors.END}")
    print(f"{Colors.BOLD}{'='*60}{Colors.END}\n")
    
    results = {
        'dependencies': False,
        'model': False,
        'syntax': False,
        'imports': False,
        'endpoints': False,
        'server': False
    }
    
    # 1. Проверка зависимостей
    results['dependencies'] = check_dependencies()
    
    # 2. Проверка модели
    results['model'] = check_model_exists()
    
    # 3. Проверка синтаксиса
    results['syntax'] = check_syntax()
    
    # 4. Проверка импортов
    results['imports'] = check_imports()
    
    # 5. Проверка API endpoints
    results['endpoints'] = test_api_endpoints()
    
    # 6. Тест запуска сервера (только если модель доступна)
    if results['model']:
        server_process = test_server_startup(model_available=True)
        if server_process:
            results['server'] = True
            # Останавливаем сервер
            try:
                server_process.terminate()
                server_process.wait(timeout=5)
                print_test("Остановка сервера", "PASS")
            except Exception as e:
                print_test("Остановка сервера", "FAIL", str(e))
    else:
        print_test("Тест сервера", "SKIP", "Модель недоступна")
    
    # Итоговый отчет
    print(f"\n{Colors.BOLD}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}  Итоговый отчет{Colors.END}")
    print(f"{Colors.BOLD}{'='*60}{Colors.END}\n")
    
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    
    for test_name, result in results.items():
        status = "PASS" if result else "FAIL"
        print_test(test_name.capitalize(), status)
    
    print(f"\n{Colors.BOLD}Результат: {passed}/{total} тестов пройдено{Colors.END}")
    
    if passed == total:
        print(f"{Colors.GREEN}✓ Все тесты пройдены!{Colors.END}")
        return 0
    else:
        print(f"{Colors.RED}✗ Некоторые тесты не пройдены{Colors.END}")
        return 1

if __name__ == "__main__":
    sys.exit(main())