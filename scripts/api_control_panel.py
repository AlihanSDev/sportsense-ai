#!/usr/bin/env python3
"""
Панель управления API серверами Sportsense AI.
Tkinter GUI для запуска/остановки серверов и тестирования функций.

Запуск:
    python scripts/api_control_panel.py
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import subprocess
import threading
import requests
import json
import os
import sys
import signal
from datetime import datetime

# Попытка импорта psutil, если нет - используем альтернативу
try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False
    print("⚠️ psutil не установлен. Некоторые функции будут ограничены.")


class ApiControlPanel:
    """Панель управления API серверами."""
    
    def __init__(self, root):
        self.root = root
        self.root.title("Sportsense AI - Панель управления API")
        self.root.geometry("900x700")
        self.root.configure(bg='#1a1a2e')
        
        # Процессы серверов
        self.qwen_process = None
        self.uefa_process = None
        
        # Статус серверов
        self.qwen_running = False
        self.uefa_running = False
        
        # Создание интерфейса
        self._create_ui()
        
        # Проверка статуса при запуске
        self._check_initial_status()
    
    def _create_ui(self):
        """Создание пользовательского интерфейса."""
        # Стили
        style = ttk.Style()
        style.theme_use('clam')
        
        # Настройка стилей
        style.configure('Title.TLabel', 
                       background='#1a1a2e', 
                       foreground='#ffffff',
                       font=('Arial', 16, 'bold'))
        
        style.configure('Subtitle.TLabel',
                       background='#1a1a2e',
                       foreground='#aaaaaa',
                       font=('Arial', 10))
        
        style.configure('Status.TLabel',
                       background='#1a1a2e',
                       foreground='#00ff88',
                       font=('Arial', 11, 'bold'))
        
        style.configure('Control.TButton',
                       font=('Arial', 10, 'bold'),
                       padding=10)
        
        style.configure('Test.TButton',
                       font=('Arial', 9),
                       padding=5)
        
        # Главный контейнер
        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Заголовок
        title_label = ttk.Label(main_frame, 
                               text="🏆 Sportsense AI Control Panel",
                               style='Title.TLabel')
        title_label.pack(pady=(0, 5))
        
        subtitle_label = ttk.Label(main_frame,
                                  text="Управление API серверами и тестирование функций",
                                  style='Subtitle.TLabel')
        subtitle_label.pack(pady=(0, 20))
        
        # Фрейм серверов
        servers_frame = ttk.LabelFrame(main_frame, text="API Серверы", padding="15")
        servers_frame.pack(fill=tk.X, pady=(0, 15))
        
        # Qwen API Server с выбором модели
        qwen_frame = ttk.Frame(servers_frame)
        qwen_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(qwen_frame, text="🤖 Qwen LLM API:").pack(side=tk.LEFT)
        
        # Выбор модели
        self.model_var = tk.StringVar(value="1.5B")
        model_combo = ttk.Combobox(qwen_frame, 
                                   textvariable=self.model_var,
                                   values=["1.5B (Q5_K_M)", "0.5B (Q4_K_M) - теги"],
                                   state="readonly",
                                   width=20)
        model_combo.pack(side=tk.LEFT, padx=5)
        
        # Выбор порта
        self.port_var = tk.StringVar(value="5000")
        port_combo = ttk.Combobox(qwen_frame,
                                  textvariable=self.port_var,
                                  values=["5000", "5002"],
                                  state="readonly",
                                  width=6)
        port_combo.pack(side=tk.LEFT, padx=5)
        
        self.qwen_status = ttk.Label(qwen_frame, text="● Остановлен", foreground='#ff4444')
        self.qwen_status.pack(side=tk.LEFT, padx=(10, 20))
        
        self.qwen_btn = ttk.Button(qwen_frame, 
                                   text="Запустить",
                                   command=self._toggle_qwen,
                                   style='Control.TButton')
        self.qwen_btn.pack(side=tk.LEFT, padx=5)
        
        ttk.Button(qwen_frame,
                  text="Проверить",
                  command=self._check_qwen_health,
                  style='Test.TButton').pack(side=tk.LEFT, padx=5)
        
        # UEFA Parser API Server
        uefa_frame = ttk.Frame(servers_frame)
        uefa_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(uefa_frame, text="⚽ UEFA Parser API (порт 5001):").pack(side=tk.LEFT)
        
        self.uefa_status = ttk.Label(uefa_frame, text="● Остановлен", foreground='#ff4444')
        self.uefa_status.pack(side=tk.LEFT, padx=(10, 20))
        
        self.uefa_btn = ttk.Button(uefa_frame,
                                  text="Запустить",
                                  command=self._toggle_uefa,
                                  style='Control.TButton')
        self.uefa_btn.pack(side=tk.LEFT, padx=5)
        
        ttk.Button(uefa_frame,
                  text="Проверить",
                  command=self._check_uefa_health,
                  style='Test.TButton').pack(side=tk.LEFT, padx=5)
        
        # Кнопка убить все процессы
        kill_frame = ttk.Frame(servers_frame)
        kill_frame.pack(fill=tk.X, pady=(15, 0))
        
        ttk.Button(kill_frame,
                  text="🛑 Остановить все Python процессы",
                  command=self._kill_all_python,
                  style='Control.TButton').pack(side=tk.LEFT)
        
        ttk.Button(kill_frame,
                  text="🔄 Обновить статус",
                  command=self._refresh_status,
                  style='Test.TButton').pack(side=tk.LEFT, padx=10)
        
        # Фрейм тестирования
        test_frame = ttk.LabelFrame(main_frame, text="Тестирование функций", padding="15")
        test_frame.pack(fill=tk.X, pady=(0, 15))
        
        # Тест генерации названия чата
        tag_frame = ttk.Frame(test_frame)
        tag_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(tag_frame, text="📝 Генерация названия чата:").pack(anchor=tk.W)
        
        tag_input_frame = ttk.Frame(tag_frame)
        tag_input_frame.pack(fill=tk.X, pady=5)
        
        self.tag_entry = ttk.Entry(tag_input_frame, width=50)
        self.tag_entry.pack(side=tk.LEFT, padx=(0, 10))
        self.tag_entry.insert(0, "Расскажи про футбол в Лиге Чемпионов")
        
        ttk.Button(tag_input_frame,
                  text="Сгенерировать",
                  command=self._test_tag_generation,
                  style='Test.TButton').pack(side=tk.LEFT)
        
        # Тест чата с LLM
        chat_frame = ttk.Frame(test_frame)
        chat_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(chat_frame, text="💬 Тест чата с LLM:").pack(anchor=tk.W)
        
        chat_input_frame = ttk.Frame(chat_frame)
        chat_input_frame.pack(fill=tk.X, pady=5)
        
        self.chat_entry = ttk.Entry(chat_input_frame, width=50)
        self.chat_entry.pack(side=tk.LEFT, padx=(0, 10))
        self.chat_entry.insert(0, "Привет! Как дела?")
        
        ttk.Button(chat_input_frame,
                  text="Отправить",
                  command=self._test_chat,
                  style='Test.TButton').pack(side=tk.LEFT)
        
        # Тест UEFA парсера
        uefa_test_frame = ttk.Frame(test_frame)
        uefa_test_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(uefa_test_frame, text="🏆 Тест UEFA парсера:").pack(side=tk.LEFT)
        
        ttk.Button(uefa_test_frame,
                  text="Получить рейтинги",
                  command=self._test_uefa_parser,
                  style='Test.TButton').pack(side=tk.LEFT, padx=10)
        
        ttk.Button(uefa_test_frame,
                  text="Свежие данные",
                  command=self._test_uefa_fresh,
                  style='Test.TButton').pack(side=tk.LEFT)
        
        # Лог вывода
        log_frame = ttk.LabelFrame(main_frame, text="Лог", padding="10")
        log_frame.pack(fill=tk.BOTH, expand=True)
        
        self.log_text = scrolledtext.ScrolledText(log_frame,
                                                   height=15,
                                                   bg='#0d0d1a',
                                                   fg='#00ff88',
                                                   font=('Consolas', 9))
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Кнопка очистки лога
        ttk.Button(log_frame,
                  text="Очистить лог",
                  command=self._clear_log,
                  style='Test.TButton').pack(pady=(5, 0))
        
        # Приветственное сообщение
        self._log("🏆 Sportsense AI Control Panel запущен")
        self._log("=" * 50)
    
    def _log(self, message, level="INFO"):
        """Добавление сообщения в лог."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        if level == "ERROR":
            prefix = "❌"
            color = "#ff4444"
        elif level == "SUCCESS":
            prefix = "✅"
            color = "#00ff88"
        elif level == "WARNING":
            prefix = "⚠️"
            color = "#ffaa00"
        else:
            prefix = "ℹ️"
            color = "#00aaff"
        
        formatted_msg = f"[{timestamp}] {prefix} {message}\n"
        
        self.log_text.insert(tk.END, formatted_msg)
        self.log_text.see(tk.END)
        self.log_text.update()
    
    def _clear_log(self):
        """Очистка лога."""
        self.log_text.delete(1.0, tk.END)
    
    def _check_initial_status(self):
        """Проверка начального статуса серверов."""
        self._check_qwen_health(silent=True)
        self._check_uefa_health(silent=True)
    
    def _refresh_status(self):
        """Обновление статуса серверов."""
        self._log("Обновление статуса серверов...")
        self._check_qwen_health(silent=False)
        self._check_uefa_health(silent=False)
    
    def _check_qwen_health(self, silent=False):
        """Проверка здоровья Qwen API."""
        port = self.port_var.get()
        try:
            response = requests.get(f"http://127.0.0.1:{port}/health", timeout=2)
            if response.status_code == 200:
                data = response.json()
                if data.get('loaded'):
                    self.qwen_status.config(text="● Работает (модель загружена)", foreground='#00ff88')
                    self.qwen_running = True
                    self.qwen_btn.config(text="Остановить")
                    if not silent:
                        self._log("Qwen API: сервер работает, модель загружена", "SUCCESS")
                else:
                    self.qwen_status.config(text="● Работает (модель не загружена)", foreground='#ffaa00')
                    self.qwen_running = True
                    self.qwen_btn.config(text="Остановить")
                    if not silent:
                        self._log("Qwen API: сервер работает, но модель не загружена", "WARNING")
            else:
                self._set_qwen_stopped()
                if not silent:
                    self._log(f"Qwen API: ошибка {response.status_code}", "ERROR")
        except requests.exceptions.ConnectionError:
            self._set_qwen_stopped()
            if not silent:
                self._log("Qwen API: сервер недоступен", "WARNING")
        except Exception as e:
            self._set_qwen_stopped()
            if not silent:
                self._log(f"Qwen API: ошибка проверки - {e}", "ERROR")
    
    def _set_qwen_stopped(self):
        """Установка статуса Qwen как остановленного."""
        self.qwen_status.config(text="● Остановлен", foreground='#ff4444')
        self.qwen_running = False
        self.qwen_btn.config(text="Запустить")
    
    def _check_uefa_health(self, silent=False):
        """Проверка здоровья UEFA Parser API."""
        try:
            response = requests.get("http://127.0.0.1:5001/health", timeout=2)
            if response.status_code == 200:
                data = response.json()
                cached = data.get('cached', False)
                self.uefa_status.config(
                    text=f"● Работает (кэш: {'да' if cached else 'нет'})",
                    foreground='#00ff88'
                )
                self.uefa_running = True
                self.uefa_btn.config(text="Остановить")
                if not silent:
                    self._log(f"UEFA Parser API: сервер работает, кэш: {cached}", "SUCCESS")
            else:
                self._set_uefa_stopped()
                if not silent:
                    self._log(f"UEFA Parser API: ошибка {response.status_code}", "ERROR")
        except requests.exceptions.ConnectionError:
            self._set_uefa_stopped()
            if not silent:
                self._log("UEFA Parser API: сервер недоступен", "WARNING")
        except Exception as e:
            self._set_uefa_stopped()
            if not silent:
                self._log(f"UEFA Parser API: ошибка проверки - {e}", "ERROR")
    
    def _set_uefa_stopped(self):
        """Установка статуса UEFA как остановленного."""
        self.uefa_status.config(text="● Остановлен", foreground='#ff4444')
        self.uefa_running = False
        self.uefa_btn.config(text="Запустить")
    
    def _toggle_qwen(self):
        """Переключение Qwen API сервера."""
        if self.qwen_running:
            self._stop_qwen()
        else:
            self._start_qwen()
    
    def _start_qwen(self):
        """Запуск Qwen API сервера с выбранной моделью."""
        model = self.model_var.get()
        port = self.port_var.get()
        
        # Выбираем скрипт в зависимости от модели
        if "0.5B" in model:
            script_name = 'qwen_api_0.5.py'
            model_name = "Qwen2.5-0.5B"
        else:
            script_name = 'qwen_api.py'
            model_name = "Qwen2.5-1.5B"
        
        self._log(f"Запуск {model_name} на порту {port}...")
        
        def run_server():
            try:
                script_path = os.path.join(os.path.dirname(__file__), script_name)
                
                # Устанавливаем переменную окружения для порта
                env = os.environ.copy()
                env['QWEN_PORT'] = port
                
                self.qwen_process = subprocess.Popen(
                    [sys.executable, script_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    env=env,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
                )
                
                # Чтение вывода в реальном времени
                for line in iter(self.qwen_process.stdout.readline, ''):
                    if line:
                        self.root.after(0, lambda l=line.strip(): self._log(f"Qwen: {l}"))
                
                self.qwen_process.wait()
                self.root.after(0, lambda: self._set_qwen_stopped())
                self.root.after(0, lambda: self._log("Qwen API сервер остановлен", "WARNING"))
                
            except Exception as e:
                self.root.after(0, lambda: self._log(f"Ошибка запуска Qwen: {e}", "ERROR"))
                self.root.after(0, lambda: self._set_qwen_stopped())
        
        thread = threading.Thread(target=run_server, daemon=True)
        thread.start()
        
        # Проверяем статус через 3 секунды
        self.root.after(3000, lambda: self._check_qwen_health(silent=False))
    
    def _stop_qwen(self):
        """Остановка Qwen API сервера."""
        self._log("Остановка Qwen API сервера...")
        
        if self.qwen_process:
            try:
                self.qwen_process.terminate()
                self.qwen_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.qwen_process.kill()
            except Exception as e:
                self._log(f"Ошибка остановки Qwen: {e}", "ERROR")
        
        # Также убиваем процесс по порту
        self._kill_process_on_port(5000)
        self._set_qwen_stopped()
        self._log("Qwen API сервер остановлен", "SUCCESS")
    
    def _toggle_uefa(self):
        """Переключение UEFA Parser API сервера."""
        if self.uefa_running:
            self._stop_uefa()
        else:
            self._start_uefa()
    
    def _start_uefa(self):
        """Запуск UEFA Parser API сервера."""
        self._log("Запуск UEFA Parser API сервера...")
        
        def run_server():
            try:
                script_path = os.path.join(os.path.dirname(__file__), 'uefa_parser_api.py')
                self.uefa_process = subprocess.Popen(
                    [sys.executable, script_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
                )
                
                # Чтение вывода в реальном времени
                for line in iter(self.uefa_process.stdout.readline, ''):
                    if line:
                        self.root.after(0, lambda l=line.strip(): self._log(f"UEFA: {l}"))
                
                self.uefa_process.wait()
                self.root.after(0, lambda: self._set_uefa_stopped())
                self.root.after(0, lambda: self._log("UEFA Parser API сервер остановлен", "WARNING"))
                
            except Exception as e:
                self.root.after(0, lambda: self._log(f"Ошибка запуска UEFA: {e}", "ERROR"))
                self.root.after(0, lambda: self._set_uefa_stopped())
        
        thread = threading.Thread(target=run_server, daemon=True)
        thread.start()
        
        # Проверяем статус через 3 секунды
        self.root.after(3000, lambda: self._check_uefa_health(silent=False))
    
    def _stop_uefa(self):
        """Остановка UEFA Parser API сервера."""
        self._log("Остановка UEFA Parser API сервера...")
        
        if self.uefa_process:
            try:
                self.uefa_process.terminate()
                self.uefa_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.uefa_process.kill()
            except Exception as e:
                self._log(f"Ошибка остановки UEFA: {e}", "ERROR")
        
        # Также убиваем процесс по порту
        self._kill_process_on_port(5001)
        self._set_uefa_stopped()
        self._log("UEFA Parser API сервер остановлен", "SUCCESS")
    
    def _kill_process_on_port(self, port):
        """Убить процесс на указанном порту."""
        if not HAS_PSUTIL:
            self._log("psutil не установлен, используем альтернативный метод...", "WARNING")
            # Альтернативный метод через netstat
            try:
                result = subprocess.run(
                    f'netstat -ano | findstr :{port}',
                    shell=True,
                    capture_output=True,
                    text=True
                )
                if result.stdout:
                    lines = result.stdout.strip().split('\n')
                    for line in lines:
                        parts = line.split()
                        if len(parts) >= 5:
                            pid = parts[-1]
                            try:
                                self._log(f"Убиваем процесс PID: {pid} на порту {port}")
                                subprocess.run(f'taskkill /F /PID {pid}', shell=True)
                            except Exception as e:
                                self._log(f"Ошибка убийства PID {pid}: {e}", "ERROR")
            except Exception as e:
                self._log(f"Ошибка поиска процесса на порту {port}: {e}", "ERROR")
            return
        
        try:
            for proc in psutil.process_iter(['pid', 'name', 'connections']):
                try:
                    for conn in proc.info['connections'] or []:
                        if conn.laddr.port == port:
                            self._log(f"Убиваем процесс {proc.info['pid']} на порту {port}")
                            os.kill(proc.info['pid'], signal.SIGTERM)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
        except Exception as e:
            self._log(f"Ошибка при убийстве процесса на порту {port}: {e}", "ERROR")
    
    def _kill_all_python(self):
        """Убить все Python процессы."""
        if not messagebox.askyesno("Подтверждение", 
                                   "Убить ВСЕ Python процессы?\nЭто может остановить другие Python программы!"):
            return
        
        self._log("Убиваем все Python процессы...")
        
        if not HAS_PSUTIL:
            self._log("psutil не установлен, используем taskkill...", "WARNING")
            try:
                subprocess.run('taskkill /F /IM python.exe', shell=True)
                self._log("Команда taskkill выполнена", "SUCCESS")
            except Exception as e:
                self._log(f"Ошибка taskkill: {e}", "ERROR")
            self._set_qwen_stopped()
            self._set_uefa_stopped()
            return
        
        killed_count = 0
        current_pid = os.getpid()
        
        try:
            for proc in psutil.process_iter(['pid', 'name']):
                try:
                    if proc.info['name'] and 'python' in proc.info['name'].lower():
                        if proc.info['pid'] != current_pid:
                            os.kill(proc.info['pid'], signal.SIGTERM)
                            killed_count += 1
                            self._log(f"Убит процесс PID: {proc.info['pid']}")
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
        except Exception as e:
            self._log(f"Ошибка при убийстве процессов: {e}", "ERROR")
        
        self._set_qwen_stopped()
        self._set_uefa_stopped()
        self._log(f"Убито {killed_count} Python процессов", "SUCCESS")
    
    def _test_tag_generation(self):
        """Тест генерации названия чата."""
        message = self.tag_entry.get().strip()
        if not message:
            self._log("Введите сообщение для теста", "WARNING")
            return
        
        self._log(f"Генерация названия для: '{message}'")
        
        # Локальная генерация на основе ключевых слов
        topic_keywords = {
            'футбол': ['футбол', 'football', 'гол', 'матч', 'лига', 'чемпионат', 'команда'],
            'баскетбол': ['баскетбол', 'basketball', 'NBA', 'корзина'],
            'хоккей': ['хоккей', 'hockey', 'NHL', 'шайба'],
            'теннис': ['теннис', 'tennis', 'ракетка'],
            'бокс': ['бокс', 'boxing', 'нокаут'],
            'формула 1': ['формула', 'F1', 'гонки'],
            'UEFA': ['UEFA', 'уефа', 'рейтинг', 'ранкинг'],
            'здоровье': ['здоровье', 'здоров', 'травма', 'лечение', 'врач'],
            'технологии': ['технологии', 'компьютер', 'программирование', 'AI', 'нейросеть'],
            'еда': ['еда', 'рецепт', 'готовить', 'кухня'],
            'путешествия': ['путешествие', 'поездка', 'отпуск'],
            'музыка': ['музыка', 'песня', 'альбом'],
            'кино': ['кино', 'фильм', 'movie', 'сериал'],
        }
        
        message_lower = message.lower()
        found_topic = None
        
        for topic, keywords in topic_keywords.items():
            for keyword in keywords:
                if keyword.lower() in message_lower:
                    found_topic = topic
                    break
            if found_topic:
                break
        
        if found_topic:
            title = f"💬 Вопрос про {found_topic}"
        else:
            words = message.split()[:4]
            title = f"💬 {' '.join(words)}"
        
        self._log(f"Сгенерированное название: '{title}'", "SUCCESS")
        
        # Если Qwen работает, попробуем через LLM
        if self.qwen_running:
            self._log("Отправка запроса к LLM для улучшенной генерации...")
            
            def test_llm():
                try:
                    prompt = f'''Создай краткое название чата (максимум 5-6 слов) на основе этого вопроса.
Только название, без кавычек.

Вопрос: "{message}"

Название:'''
                    
                    response = requests.post(
                        "http://127.0.0.1:5000/generate",
                        json={'prompt': prompt, 'max_tokens': 50},
                        timeout=10
                    )
                    
                    if response.status_code == 200:
                        data = response.json()
                        llm_title = data.get('text', '').strip()
                        if llm_title:
                            self.root.after(0, lambda: self._log(f"LLM название: '💬 {llm_title}'", "SUCCESS"))
                        else:
                            self.root.after(0, lambda: self._log("LLM вернул пустой ответ", "WARNING"))
                    else:
                        self.root.after(0, lambda: self._log(f"LLM ошибка: {response.status_code}", "ERROR"))
                        
                except Exception as e:
                    self.root.after(0, lambda: self._log(f"Ошибка LLM: {e}", "ERROR"))
            
            thread = threading.Thread(target=test_llm, daemon=True)
            thread.start()
    
    def _test_chat(self):
        """Тест чата с LLM."""
        if not self.qwen_running:
            self._log("Qwen API не запущен! Сначала запустите сервер.", "ERROR")
            return
        
        message = self.chat_entry.get().strip()
        if not message:
            self._log("Введите сообщение для чата", "WARNING")
            return
        
        self._log(f"Отправка сообщения: '{message}'")
        
        def send_chat():
            try:
                port = self.port_var.get()
                response = requests.post(
                    f"http://127.0.0.1:{port}/chat",
                    json={'message': message, 'max_tokens': 256},
                    timeout=30
                )
                
                if response.status_code == 200:
                    data = response.json()
                    bot_response = data.get('response', '')
                    tokens = data.get('tokens_used', 0)
                    self.root.after(0, lambda: self._log(f"Ответ бота: {bot_response}", "SUCCESS"))
                    self.root.after(0, lambda: self._log(f"Использовано токенов: {tokens}"))
                    
                    # Генерация названия чата
                    try:
                        title_response = requests.post(
                            f"http://127.0.0.1:{port}/generate_title",
                            json={'message': message},
                            timeout=10
                        )
                        if title_response.status_code == 200:
                            title_data = title_response.json()
                            chat_title = title_data.get('title', '')
                            if chat_title:
                                self.root.after(0, lambda: self._log(f"📝 Название чата: '{chat_title}'", "SUCCESS"))
                    except Exception as title_error:
                        self.root.after(0, lambda: self._log(f"Не удалось сгенерировать название: {title_error}", "WARNING"))
                else:
                    self.root.after(0, lambda: self._log(f"Ошибка чата: {response.status_code}", "ERROR"))
                    
            except Exception as e:
                self.root.after(0, lambda: self._log(f"Ошибка чата: {e}", "ERROR"))
        
        thread = threading.Thread(target=send_chat, daemon=True)
        thread.start()
    
    def _test_uefa_parser(self):
        """Тест UEFA парсера (из кэша)."""
        if not self.uefa_running:
            self._log("UEFA Parser API не запущен! Сначала запустите сервер.", "ERROR")
            return
        
        self._log("Запрос рейтингов UEFA (из кэша)...")
        
        def fetch_rankings():
            try:
                response = requests.get("http://127.0.0.1:5001/rankings", timeout=30)
                
                if response.status_code == 200:
                    data = response.json()
                    rankings = data.get('data', [])
                    source = data.get('source', 'unknown')
                    count = len(rankings)
                    
                    self.root.after(0, lambda: self._log(f"Получено {count} записей (источник: {source})", "SUCCESS"))
                    
                    # Показываем топ-5
                    for i, team in enumerate(rankings[:5]):
                        association = team.get('association', team.get('col_0', 'Unknown'))
                        points = team.get('points', team.get('col_3', 'N/A'))
                        self.root.after(0, lambda r=i+1, a=association, p=points: 
                                       self._log(f"  {r}. {a} - {p} очков"))
                    
                    if count > 5:
                        self.root.after(0, lambda: self._log(f"  ... и еще {count - 5} записей"))
                        
                else:
                    self.root.after(0, lambda: self._log(f"Ошибка UEFA: {response.status_code}", "ERROR"))
                    
            except Exception as e:
                self.root.after(0, lambda: self._log(f"Ошибка UEFA: {e}", "ERROR"))
        
        thread = threading.Thread(target=fetch_rankings, daemon=True)
        thread.start()
    
    def _test_uefa_fresh(self):
        """Тест UEFA парсера (свежие данные)."""
        if not self.uefa_running:
            self._log("UEFA Parser API не запущен! Сначала запустите сервер.", "ERROR")
            return
        
        self._log("Запрос свежих данных UEFA (парсинг может занять время)...")
        
        def fetch_fresh():
            try:
                response = requests.get("http://127.0.0.1:5001/rankings/fresh", timeout=120)
                
                if response.status_code == 200:
                    data = response.json()
                    rankings = data.get('data', [])
                    count = len(rankings)
                    
                    self.root.after(0, lambda: self._log(f"Получено {count} свежих записей", "SUCCESS"))
                    
                    # Показываем топ-5
                    for i, team in enumerate(rankings[:5]):
                        association = team.get('association', team.get('col_0', 'Unknown'))
                        points = team.get('points', team.get('col_3', 'N/A'))
                        self.root.after(0, lambda r=i+1, a=association, p=points: 
                                       self._log(f"  {r}. {a} - {p} очков"))
                    
                    if count > 5:
                        self.root.after(0, lambda: self._log(f"  ... и еще {count - 5} записей"))
                        
                else:
                    self.root.after(0, lambda: self._log(f"Ошибка UEFA: {response.status_code}", "ERROR"))
                    
            except Exception as e:
                self.root.after(0, lambda: self._log(f"Ошибка UEFA: {e}", "ERROR"))
        
        thread = threading.Thread(target=fetch_fresh, daemon=True)
        thread.start()


def main():
    """Точка входа."""
    root = tk.Tk()
    app = ApiControlPanel(root)
    
    # Обработка закрытия окна
    def on_closing():
        if messagebox.askokcancel("Выход", "Остановить все серверы и выйти?"):
            app._stop_qwen()
            app._stop_uefa()
            root.destroy()
    
    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()


if __name__ == "__main__":
    main()