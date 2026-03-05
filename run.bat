@echo off
echo ========================================
echo   Запуск TEST APP на Small Phone
echo ========================================
echo.

echo [1/5] Запуск эмулятора Small Phone...
flutter emulators --launch Small_Phone
timeout /t 30 /nobreak >nul

echo [2/5] Очистка кэша...
flutter clean

echo [3/5] Установка зависимостей...
flutter pub get

echo [4/5] Запуск приложения (uninstall + hot reload)...
flutter run -d Small_Phone --uninstall

echo.
echo ========================================
echo   Готово!
echo ========================================
pause
