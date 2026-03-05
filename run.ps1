Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Запуск TEST APP на Small Phone" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Запуск эмулятора Small Phone..." -ForegroundColor Yellow
flutter emulators --launch Small_Phone

Write-Host "[2/5] Ожидание загрузки (30 сек)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "[3/5] Очистка кэша..." -ForegroundColor Yellow
flutter clean

Write-Host "[4/5] Установка зависимостей..." -ForegroundColor Yellow
flutter pub get

Write-Host "[5/5] Запуск приложения (uninstall + hot reload)..." -ForegroundColor Yellow
flutter run -d Small_Phone --uninstall

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Готово!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
