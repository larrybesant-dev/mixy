#!/usr/bin/env pwsh
# Create 3 Crashlytics monitoring alerts using gcloud with proper JSON format

$ProjectId = "mixvy-v2"
$ChannelId = "projects/mixvy-v2/notificationChannels/5103384296039862868"
$TempDir = [System.IO.Path]::GetTempPath()

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Creating 3 MixVy Crashlytics Monitoring Alerts       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Alert 1: CRITICAL (Emergency Severity)
Write-Host "[1/3] Creating CRITICAL Alert..." -ForegroundColor Yellow
Write-Host "  Name: MixVy Production - CRITICAL Network Recovery Failure"
Write-Host "  Trigger: Emergency severity logs `(immediate`)"

$Alert1Json = @{
    displayName = "MixVy Production - CRITICAL Network Recovery Failure"
    combiner = "OR"
    conditions = @(
        @{
            displayName = "Emergency/FATAL severity errors"
            conditionThreshold = @{
                filter = 'severity="EMERGENCY"'
                comparison = "COMPARISON_GT"
                thresholdValue = 0
                duration = "60s"
            }
        }
    )
    notificationChannels = @($ChannelId)
    alertStrategy = @{
        autoClose = "259200s"
    }
} | ConvertTo-Json -Depth 10

$Alert1File = Join-Path $TempDir "alert1_critical.json"
Set-Content -Path $Alert1File -Value $Alert1Json -Encoding UTF8

try {
    $result = & gcloud alpha monitoring policies create --policy-from-file=$Alert1File --project=$ProjectId 2>&1
    Write-Host "  ✅ Alert 1 created successfully`n" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Alert 1 creation issue: $_`n" -ForegroundColor Yellow
}

# Alert 2: ERROR (5+ in 5 minutes)
Write-Host "[2/3] Creating ERROR Alert..." -ForegroundColor Yellow
Write-Host "  Name: MixVy Production - ERROR Reconnection Failures"
Write-Host "  Trigger: 5+ ERROR level logs in 5 minutes"

$Alert2Json = @{
    displayName = "MixVy Production - ERROR Reconnection Failures"
    combiner = "OR"
    conditions = @(
        @{
            displayName = "5+ error logs in 5 minutes"
            conditionThreshold = @{
                filter = 'severity="ERROR"'
                comparison = "COMPARISON_GT"
                thresholdValue = 5
                duration = "300s"
                aggregations = @(
                    @{
                        alignmentPeriod = "60s"
                        perSeriesAligner = "ALIGN_COUNT"
                    }
                )
            }
        }
    )
    notificationChannels = @($ChannelId)
    alertStrategy = @{
        autoClose = "259200s"
    }
} | ConvertTo-Json -Depth 10

$Alert2File = Join-Path $TempDir "alert2_error.json"
Set-Content -Path $Alert2File -Value $Alert2Json -Encoding UTF8

try {
    $result = & gcloud alpha monitoring policies create --policy-from-file=$Alert2File --project=$ProjectId 2>&1
    Write-Host "  ✅ Alert 2 created successfully`n" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Alert 2 creation issue: $_`n" -ForegroundColor Yellow
}

# Alert 3: WARNING (3+ in 5 minutes)
Write-Host "[3/3] Creating WARNING Alert..." -ForegroundColor Yellow
Write-Host "  Name: MixVy Production - WARNING Connection Health Degrading"
Write-Host "  Trigger: 3+ WARNING level logs in 5 minutes"

$Alert3Json = @{
    displayName = "MixVy Production - WARNING Connection Health Degrading"
    combiner = "OR"
    conditions = @(
        @{
            displayName = "3+ warning logs in 5 minutes"
            conditionThreshold = @{
                filter = 'severity="WARNING"'
                comparison = "COMPARISON_GT"
                thresholdValue = 3
                duration = "300s"
                aggregations = @(
                    @{
                        alignmentPeriod = "60s"
                        perSeriesAligner = "ALIGN_COUNT"
                    }
                )
            }
        }
    )
    notificationChannels = @($ChannelId)
    alertStrategy = @{
        autoClose = "259200s"
    }
} | ConvertTo-Json -Depth 10

$Alert3File = Join-Path $TempDir "alert3_warning.json"
Set-Content -Path $Alert3File -Value $Alert3Json -Encoding UTF8

try {
    $result = & gcloud alpha monitoring policies create --policy-from-file=$Alert3File --project=$ProjectId 2>&1
    Write-Host "  ✅ Alert 3 created successfully`n" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Alert 3 creation issue: $_`n" -ForegroundColor Yellow
}

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  Verification Steps                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Listing all created policies...`n" -ForegroundColor Yellow

try {
    $policies = & gcloud alpha monitoring policies list --project=$ProjectId --format="table(displayName, enabled)"
    Write-Host $policies -ForegroundColor Green
} catch {
    Write-Host "Could not list policies: $_" -ForegroundColor Yellow
}

Write-Host "`n✅ All alerts created!`n" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Check Firebase Console: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies"
Write-Host "2. Verify all 3 alerts are listed and enabled"
Write-Host "3. Test alert delivery by simulating a connection failure`n" -ForegroundColor Cyan
