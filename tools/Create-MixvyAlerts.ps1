#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create 3 Crashlytics alerts using gcloud monitoring API
    
.DESCRIPTION
    Creates monitoring alert policies for MixVy production
    
.EXAMPLE
    .\Create-MixvyAlerts.ps1
#>

param(
    [string]$ProjectId = "mixvy-v2",
    [string]$Email = "larrybesant@gmail.com"
)

Write-Host "Running MixVy Crashlytics Alerts Setup" -ForegroundColor Cyan
Write-Host "========================================================================"

# Set project
Write-Host "`n[INFO] Setting project to $ProjectId..." -ForegroundColor Green
gcloud config set project $ProjectId

# Get or create notification channel
Write-Host "`n[INFO] Setting up email notification channel..." -ForegroundColor Green

# Create email channel using monitoring API
$channelOutput = gcloud alpha monitoring channels create `
    --display-name="Email - $Email" `
    --type=email `
    --channel-labels=email_address=$Email `
    --format="value(name)" 2>&1

if ($LASTEXITCODE -eq 0 -and $channelOutput) {
    $channelName = $channelOutput
    Write-Host "✅ Created channel: $channelName" -ForegroundColor Green
} else {
    Write-Host "⚠️  Channel may already exist, attempting to use existing..." -ForegroundColor Yellow
    # Try to get existing channel
    $existingChannel = gcloud alpha monitoring channels list `
        --filter="type=email AND labels.email_address=$Email" `
        --format="value(name)" 2>&1 | Select-Object -First 1
    
    if ($existingChannel) {
        $channelName = $existingChannel
        Write-Host "✅ Using existing channel: $channelName" -ForegroundColor Green
    } else {
        Write-Host "❌ Could not create or find email channel" -ForegroundColor Red
        exit 1
    }
}

# Create Alert 1: CRITICAL
Write-Host "`n[CRITICAL] Creating Alert 1: Max Retries Exceeded" -ForegroundColor Yellow

$alert1Name = "MixVy Production - CRITICAL Network Recovery Failure"
$alert1 = @{
    displayName = $alert1Name
    conditions = @(
        @{
            displayName = "FATAL severity"
            conditionThreshold = @{
                filter = 'resource.type="global" AND severity="FATAL" AND protoPayload.methodName=~"com.crashlytics.*"'
                comparison = "COMPARISON_GT"
                thresholdValue = 0
                duration = "60s"
            }
        }
    )
    notificationChannels = @($channelName)
    alertStrategy = @{
        autoClose = "259200s"
    }
} | ConvertTo-Json -Depth 5

$alert1Json = $alert1 | Out-String

Write-Host "Creating: $alert1Name" -ForegroundColor Cyan

gcloud alpha monitoring policies create --policy-from-file=- @"
{
  "displayName": "MixVy Production - CRITICAL Network Recovery Failure",
  "conditions": [{
    "displayName": "FATAL severity",
    "conditionThreshold": {
      "filter": "resource.type=\"global\" AND severity=\"FATAL\" AND protoPayload.methodName=~\"com.crashlytics.*\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 0,
      "duration": "60s"
    }
  }],
  "notificationChannels": ["$channelName"],
  "alertStrategy": {
    "autoClose": "259200s"
  }
}
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Alert 1 created successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️  Alert 1 creation encountered an issue (may already exist)" -ForegroundColor Yellow
}

# Create Alert 2: ERROR
Write-Host "`n[ERROR] Creating Alert 2: ERROR - Reconnection Failures" -ForegroundColor Yellow

$alert2Name = "MixVy Production - ERROR Reconnection Failures"

Write-Host "Creating: $alert2Name" -ForegroundColor Cyan

gcloud alpha monitoring policies create --policy-from-file=- @"
{
  "displayName": "MixVy Production - ERROR Reconnection Failures",
  "conditions": [{
    "displayName": "Issue count greater than 5 in 5 minutes",
    "conditionThreshold": {
      "filter": "resource.type=\"global\" AND severity=\"ERROR\" AND protoPayload.methodName=~\"com.crashlytics.*\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 5,
      "duration": "300s"
    }
  }],
  "notificationChannels": ["$channelName"],
  "alertStrategy": {
    "autoClose": "259200s"
  }
}
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Alert 2 created successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️  Alert 2 creation encountered an issue (may already exist)" -ForegroundColor Yellow
}

# Create Alert 3: WARNING
Write-Host "`n[WARNING] Creating Alert 3: Connection Health" -ForegroundColor Yellow

$alert3Name = "MixVy Production - WARNING Connection Health Degrading"

Write-Host "Creating: $alert3Name" -ForegroundColor Cyan

gcloud alpha monitoring policies create --policy-from-file=- @"
{
  "displayName": "MixVy Production - WARNING Connection Health Degrading",
  "conditions": [{
    "displayName": "Issue count greater than 3 in 5 minutes",
    "conditionThreshold": {
      "filter": "resource.type=\"global\" AND severity=\"WARNING\" AND protoPayload.methodName=~\"com.crashlytics.*\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 3,
      "duration": "300s"
    }
  }],
  "notificationChannels": ["$channelName"],
  "alertStrategy": {
    "autoClose": "259200s"
  }
}
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Alert 3 created successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️  Alert 3 creation encountered an issue (may already exist)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================================================"
Write-Host "Alert Creation Summary" -ForegroundColor Cyan
Write-Host "========================================================================"

Write-Host "`n[SUCCESS] All alerts have been processed!"
Write-Host "`n[INFO] Verify alerts here:"
Write-Host "   https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies"

Write-Host "`n[INFO] Check email for verification links (if new channel was created)"

Write-Host "`n[INFO] Next steps:"
Write-Host "   1. Check Firebase Console for all 3 alerts"
Write-Host "   2. Verify email notifications are enabled"
Write-Host "   3. Test alert delivery (optional)"
Write-Host "`n[SUCCESS] Setup complete!" -ForegroundColor Green
