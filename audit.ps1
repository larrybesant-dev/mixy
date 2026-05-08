# MixVy Project Auditor & Fixer
# This script runs a full scan of the project to ensure code quality and stability.

Write-Host "🚀 Starting MixVy Project Audit..." -ForegroundColor Cyan

# 1. Clean and Fetch Dependencies
Write-Host "`n📦 Checking dependencies..." -ForegroundColor Yellow
flutter pub get

# 2. Format Code
Write-Host "`n🎨 Formatting code..." -ForegroundColor Yellow
flutter format lib test

# 3. Static Analysis (The "Scan")
Write-Host "`n🔍 Running static analysis..." -ForegroundColor Yellow
$analysis = flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Analysis found issues:" -ForegroundColor Red
    Write-Host $analysis
} else {
    Write-Host "✅ Analysis passed!" -ForegroundColor Green
}

# 4. Run Unit Tests
Write-Host "`n🧪 Running unit tests..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Some tests failed!" -ForegroundColor Red
} else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
}

# 5. Scan for TODOs (The "Audit")
Write-Host "`n📝 Scanning for pending tasks (TODOs)..." -ForegroundColor Yellow
$todos = Select-String -Path "lib\**\*.dart" -Pattern "TODO"
if ($todos) {
    Write-Host "⚠️ Found $($todos.Count) pending TODOs:" -ForegroundColor DarkYellow
    foreach ($todo in $todos) {
        $cleanPath = $todo.Path.Replace("C:\MixVy\", "")
        Write-Host "  - $($cleanPath):$($todo.LineNumber) -> $($todo.Line.Trim())"
    }
} else {
    Write-Host "✅ No pending TODOs found!" -ForegroundColor Green
}

Write-Host "`n✨ Audit Complete!" -ForegroundColor Cyan
