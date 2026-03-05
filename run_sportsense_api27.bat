@echo off
echo ========================================
echo   Запуск TEST APP на CosmoChat API 27
echo ========================================
echo.

echo [1/5] Запуск эмулятора SportSense_API_27 (cold boot)...
flutter emulators --launch SportSense_API_27 --cold

REM дождаться пока устройство появится в списке flutter devices
for /l %%i in (1,1,30) do (
    flutter devices | find "SportSense_API_27" >nul && goto device_ready
    timeout /t 2 /nobreak >nul
)
echo Устройство не появилось в списке за 1 минуту, продолжаем...
:device_ready
timeout /t 15 /nobreak >nul

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
