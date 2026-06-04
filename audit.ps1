# MixVy Project Auditor & Fixer
# This script runs a full scan of the project to ensure code quality and stability.

$ErrorActionPreference = "Continue"

Write-Host "--- MixVy Project Audit ---" -ForegroundColor Cyan

# 1. Clean and Fetch Dependencies
Write-Host "1. Checking dependencies..." -ForegroundColor Yellow
& flutter pub get

# 2. Format Code
Write-Host "2. Formatting code..." -ForegroundColor Yellow
& dart format lib integration_test

# 3. Static Analysis (The "Scan")
Write-Host "3. Running static analysis..." -ForegroundColor Yellow
$analysis = & flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "!! Analysis found issues !!" -ForegroundColor Red
    Write-Host $analysis
} else {
    Write-Host "OK: Analysis passed!" -ForegroundColor Green
}

# 4. Run Unit Tests
Write-Host "4. Running unit tests..." -ForegroundColor Yellow
if (Test-Path "test") {
    & flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Host "!! Some tests failed !!" -ForegroundColor Red
    } else {
        Write-Host "OK: All tests passed!" -ForegroundColor Green
    }
} else {
    Write-Host "OK: No unit tests found (no 'test' directory)." -ForegroundColor Green
}

# 5. Scan for TODOs (The "Audit")
Write-Host "5. Scanning for pending tasks (TODOs)..." -ForegroundColor Yellow
# Note: This might be noisy, but it's good to see what's left.
$todos = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse | Select-String -Pattern "TODO"
if ($todos) {
    Write-Host "Found $($todos.Count) pending TODOs:" -ForegroundColor DarkYellow
    foreach ($todo in $todos) {
        $cleanPath = $todo.Path.Replace("C:\MixVy\", "")
        Write-Host "  - $($cleanPath):$($todo.LineNumber) -> $($todo.Line.Trim())"
    }
} else {
    Write-Host "OK: No pending TODOs found!" -ForegroundColor Green
}

Write-Host "--- Audit Complete ---" -ForegroundColor Cyan
