#!/usr/bin/env pwsh
# Create 3 Crashlytics alerts using gcloud

$ProjectId = "mixvy-v2"
$ChannelId = "projects/mixvy-v2/notificationChannels/5103384296039862868"
$TempDir = $env:TEMP

Write-Host "`n[SUCCESS] Using notification channel" -ForegroundColor Green

# Create Alert 1: CRITICAL
Write-Host "`n[1/3] Creating CRITICAL Alert..." -ForegroundColor Cyan

$alert1 = @{
  displayName = "MixVy Production - CRITICAL Network Recovery Failure"
  combiner = "OR"
  conditions = @(
    @{
      displayName = "FATAL severity errors"
      conditionThreshold = @{
        filter = 'resource.type="global" AND severity="FATAL"'
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
}

$alert1File = "$TempDir/alert1.json"
$alert1 | ConvertTo-Json -Depth 10 | Set-Content -Path $alert1File
gcloud alpha monitoring policies create --policy-from-file=$alert1File --project=$ProjectId 2>&1 | Select-Object -First 2
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Alert 1 created" -ForegroundColor Green } else { Write-Host "[WARN] Alert 1 issue" -ForegroundColor Yellow }

# Create Alert 2: ERROR  
Write-Host "`n[2/3] Creating ERROR Alert..." -ForegroundColor Cyan

$alert2 = @{
  displayName = "MixVy Production - ERROR Reconnection Failures"
  combiner = "OR"
  conditions = @(
    @{
      displayName = "5+ errors in 5 minutes"
      conditionThreshold = @{
        filter = 'resource.type="global" AND severity="ERROR"'
        comparison = "COMPARISON_GT"
        thresholdValue = 5
        duration = "300s"
      }
    }
  )
  notificationChannels = @($ChannelId)
  alertStrategy = @{
    autoClose = "259200s"
  }
}

$alert2File = "$TempDir/alert2.json"
$alert2 | ConvertTo-Json -Depth 10 | Set-Content -Path $alert2File
gcloud alpha monitoring policies create --policy-from-file=$alert2File --project=$ProjectId 2>&1 | Select-Object -First 2
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Alert 2 created" -ForegroundColor Green } else { Write-Host "[WARN] Alert 2 issue" -ForegroundColor Yellow }

# Create Alert 3: WARNING
Write-Host "`n[3/3] Creating WARNING Alert..." -ForegroundColor Cyan

$alert3 = @{
  displayName = "MixVy Production - WARNING Connection Health Degrading"
  combiner = "OR"
  conditions = @(
    @{
      displayName = "3+ warnings in 5 minutes"
      conditionThreshold = @{
        filter = 'resource.type="global" AND severity="WARNING"'
        comparison = "COMPARISON_GT"
        thresholdValue = 3
        duration = "300s"
      }
    }
  )
  notificationChannels = @($ChannelId)
  alertStrategy = @{
    autoClose = "259200s"
  }
}

$alert3File = "$TempDir/alert3.json"
$alert3 | ConvertTo-Json -Depth 10 | Set-Content -Path $alert3File
gcloud alpha monitoring policies create --policy-from-file=$alert3File --project=$ProjectId 2>&1 | Select-Object -First 2
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Alert 3 created" -ForegroundColor Green } else { Write-Host "[WARN] Alert 3 issue" -ForegroundColor Yellow }

# Cleanup
Remove-Item -Path $alert1File -ErrorAction SilentlyContinue
Remove-Item -Path $alert2File -ErrorAction SilentlyContinue
Remove-Item -Path $alert3File -ErrorAction SilentlyContinue

Write-Host "`n[SUCCESS] All alerts processed!" -ForegroundColor Green
Write-Host "`n[INFO] View alerts at:"
Write-Host "   https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies" -ForegroundColor Cyan
Write-Host "`n[INFO] Check email for verification links"
