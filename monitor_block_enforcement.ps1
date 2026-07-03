#!/usr/bin/env pwsh

# 🔍 Real-time Block Enforcement Monitoring
# Streams Firebase Cloud Function logs and alerts on block enforcement events

Write-Host "🚀 Starting Block Enforcement Monitoring..." -ForegroundColor Green
Write-Host "📡 Listening for validateMessageBlockEnforcement triggers..." -ForegroundColor Cyan
Write-Host "`nMonitoring will show:" -ForegroundColor Yellow
Write-Host "  ✅ Block enforcement triggered"
Write-Host "  ❌ Errors or timeouts"
Write-Host "  📊 Execution time and memory usage"
Write-Host "`nPress Ctrl+C to stop monitoring`n" -ForegroundColor Gray

# Array to track recent enforcement events
$enforcementEvents = @()

# Start Firebase function logs stream
$logProcess = Start-Process -FilePath "firebase" -ArgumentList "functions:log", "--only", "validateMessageBlockEnforcement", "--project=mixvy-v2" `
    -PassThru -NoNewWindow -RedirectStandardOutput .\block-enforcement-logs.txt

Write-Host "📝 Logs saved to: ./block-enforcement-logs.txt" -ForegroundColor Gray

# Monitor log file for enforcement events
$lastPosition = 0
$checkInterval = 2  # Check every 2 seconds

try {
    while ($true) {
        Start-Sleep -Seconds $checkInterval
        
        if (Test-Path .\block-enforcement-logs.txt) {
            $content = Get-Content .\block-enforcement-logs.txt
            
            # Check for enforcement events
            if ($content -like "*blocked*" -or $content -like "*enforcement*") {
                Write-Host "🚨 BLOCK ENFORCEMENT EVENT DETECTED!" -ForegroundColor Red -BackgroundColor Yellow
                
                # Show last 5 lines of logs
                $lines = $content -split "`n"
                $recentLines = $lines | Select-Object -Last 10
                Write-Host $recentLines -ForegroundColor White
                Write-Host "`n"
            }
            
            # Check for errors
            if ($content -like "*error*" -or $content -like "*Error*") {
                Write-Host "⚠️ ERROR DETECTED!" -ForegroundColor Red
                Write-Host $content -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "Monitoring stopped" -ForegroundColor Yellow
} finally {
    Stop-Process -Id $logProcess.Id -ErrorAction SilentlyContinue
    Write-Host "`n✅ Monitoring closed" -ForegroundColor Green
}
