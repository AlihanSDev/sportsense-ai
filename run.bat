@echo off
echo ========================================
echo   Запуск TEST APP на Small Phone
echo ========================================
echo.

echo [1/5] Запуск эмулятора Small Phone (cold boot)...
flutter emulators --launch Small_Phone --cold

REM дождаться пока устройство появится в списке flutter devices
for /l %%i in (1,1,30) do (
    flutter devices | find "Small Phone" >nul && goto device_ready
    timeout /t 2 /nobreak >nul
)
echo Устройство не появилось в списке за 1 минуту, продолжаем...
:device_ready
timeout /t 15 /nobreak >nul

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
