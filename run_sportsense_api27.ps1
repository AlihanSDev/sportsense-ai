Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Запуск SportSense API на SportSense API 27" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Запуск эмулятора SportSense API 27 (cold boot)..." -ForegroundColor Yellow
flutter emulators --launch SportSense_API_27 --cold

Write-Host "[2/5] Ожидание и подключение устройства..." -ForegroundColor Yellow
for ($i=0; $i -lt 30; $i++) {
    if (flutter devices | Select-String "SportSense_API_27") { break }
    Start-Sleep -Seconds 2
}
Start-Sleep -Seconds 15

Write-Host "[3/5] Очистка кэша..." -ForegroundColor Yellow
flutter clean

Write-Host "[4/5] Установка зависимостей..." -ForegroundColor Yellow
flutter pub get

Write-Host "[5/5] Запуск приложения (uninstall + hot reload)..." -ForegroundColor Yellow
flutter run -d SportSense_API_27 --uninstall

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Готово!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green