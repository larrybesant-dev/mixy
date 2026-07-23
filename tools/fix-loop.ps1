# MixVy Auto Fix Loop (working version)

Set-Location C:\MixVy

Write-Host "🚀 Starting MixVy Auto Fix Loop..." -ForegroundColor Cyan

for ($i = 1; $i -le 15; $i++) {

    Write-Host "`n======================" -ForegroundColor Yellow
    Write-Host "Iteration $i" -ForegroundColor Yellow
    Write-Host "======================`n" -ForegroundColor Yellow

    dart format lib
    flutter pub get

    $output = flutter analyze 2>&1
    $output | Tee-Object analyze_log.txt

    $errors = ($output | Select-String "error -|Expected|Missing|Unexpected|Can't be assigned").Count

    Write-Host "`nErrors: $errors" -ForegroundColor Red

    if ($errors -eq 0) {
        Write-Host "`n🎉 CLEAN BUILD ACHIEVED" -ForegroundColor Green
        break
    }

    Start-Sleep -Seconds 2
}

Write-Host "`nDONE" -ForegroundColor Green
