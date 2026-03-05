@echo off
echo ========================================
echo   Запуск TEST APP на CosmoChat API 27
echo ========================================
echo.

echo [1/4] Запуск эмулятора CosmoChat_API_27...
flutter emulators --launch CosmoChat_API_27
timeout /t 30 /nobreak >nul

echo [2/4] Очистка кэша...
flutter clean

echo [3/4] Установка зависимостей...
flutter pub get

echo [4/4] Запуск приложения (uninstall + hot reload)...
flutter run -d CosmoChat_API_27 --uninstall

echo.
echo ========================================
echo   Готово!
echo ========================================
pause
