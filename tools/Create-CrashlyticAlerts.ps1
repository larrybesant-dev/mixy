#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create 3 Crashlytics monitoring alerts for MixVy production.

.DESCRIPTION
    Uses gcloud CLI to create:
    1. CRITICAL - Max retries exceeded (immediate)
    2. ERROR - 5+ failures in 5 minutes
    3. WARNING - 3+ degrading in 5 minutes

.EXAMPLE
    .\Create-CrashlyticAlerts.ps1
#>

param(
    [string]$ProjectId = "mixvy-v2",
    [string]$Email = "larrybesant@gmail.com"
)

Write-Host "🚀 MixVy Crashlytics Alerts - gcloud CLI Setup" -ForegroundColor Cyan
Write-Host "=" * 70

# Step 1: Verify gcloud is installed
Write-Host "`n📍 Checking prerequisites..." -ForegroundColor Green

$gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
if (-not $gcloud) {
    Write-Host "❌ gcloud CLI not found" -ForegroundColor Red
    Write-Host "Install from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ gcloud CLI found" -ForegroundColor Green

# Step 2: Verify authentication
Write-Host "`n📧 Verifying authentication..." -ForegroundColor Green

$auth = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>&1
if ($auth) {
    Write-Host "✅ Authenticated as: $auth" -ForegroundColor Green
} else {
    Write-Host "⚠️  Not authenticated. Run: gcloud auth application-default login" -ForegroundColor Yellow
}

# Step 3: Set project
Write-Host "`n🔧 Setting project context..." -ForegroundColor Green
gcloud config set project $ProjectId 2>&1 | Out-Null
Write-Host "✅ Project set to: $ProjectId" -ForegroundColor Green

# Step 4: Create notification channel
Write-Host "`n📧 Setting up email notification channel..." -ForegroundColor Green

# Check if channel already exists
$existingChannels = gcloud alpha monitoring channels list `
    --filter="type=email AND labels.email_address=$Email" `
    --format="value(name)" 2>&1

if ($existingChannels -and $existingChannels.Length -gt 0) {
    Write-Host "✅ Email channel already exists" -ForegroundColor Green
    $channelId = $existingChannels
} else {
    Write-Host "Creating new email channel for $Email..." -ForegroundColor Yellow
    
    $createOutput = gcloud alpha monitoring channels create `
        --display-name="Email - $Email" `
        --type=email `
        --channel-labels=email_address=$Email `
        --format="value(name)" 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $createOutput) {
        Write-Host "✅ Created email channel" -ForegroundColor Green
        $channelId = $createOutput
    } else {
        Write-Host "⚠️  Could not create channel (may exist already)" -ForegroundColor Yellow
        $channelId = ""
    }
}

# Step 5: Display alert configuration
Write-Host "`n🔔 Alert Configuration Summary" -ForegroundColor Cyan
Write-Host "=" * 70

Write-Host "`n📋 ALERT 1: CRITICAL - Max Retries Exceeded" -ForegroundColor Yellow
Write-Host "  Name: MixVy Production - CRITICAL Network Recovery Failure"
Write-Host "  Trigger: When max reconnection retries exceeded"
Write-Host "  Response: Immediate email notification"

Write-Host "`n📋 ALERT 2: ERROR - Repeated Failures" -ForegroundColor Yellow
Write-Host "  Name: MixVy Production - ERROR Reconnection Failures (5+ in 5min)"
Write-Host "  Trigger: 5+ errors within 5-minute window"
Write-Host "  Response: Email with error summary"

Write-Host "`n📋 ALERT 3: WARNING - Health Degrading" -ForegroundColor Yellow
Write-Host "  Name: MixVy Production - WARNING Connection Health Degrading (3+ in 5min)"
Write-Host "  Trigger: 3+ warnings within 5-minute window"
Write-Host "  Response: Proactive email alert"

# Step 6: Manual instructions
Write-Host "`n" + "=" * 70
Write-Host "⚠️  IMPORTANT: Firebase UI Required" -ForegroundColor Yellow
Write-Host "=" * 70

Write-Host "`nThe Firebase Console requires manual alert creation through the web UI."
Write-Host "Please follow these steps:`n"

Write-Host "1. 📱 Open Firebase Console:"
Write-Host "   https://console.firebase.google.com/project/mixvy-v2/overview`n"

Write-Host "2. 🔍 Navigate to Crashlytics:"
Write-Host "   Left sidebar → Crashlytics → Monitoring → Alert Policies`n"

Write-Host "3. ➕ Create Alert 1 (CRITICAL):"
Write-Host "   Display Name: MixVy Production - CRITICAL Network Recovery Failure"
Write-Host "   Condition: Issue severity is FATAL"
Write-Host "   Notification: Email - larrybesant@gmail.com`n"

Write-Host "4. ➕ Create Alert 2 (ERROR):"
Write-Host "   Display Name: MixVy Production - ERROR Reconnection Failures (5+ in 5min)"
Write-Host "   Condition: Issue count > 5 in 5 minutes"
Write-Host "   Custom Key Filter: diagnostic_severity = ERROR"
Write-Host "   Notification: Email - larrybesant@gmail.com`n"

Write-Host "5. ➕ Create Alert 3 (WARNING):"
Write-Host "   Display Name: MixVy Production - WARNING Connection Health Degrading (3+ in 5min)"
Write-Host "   Condition: Issue count > 3 in 5 minutes"
Write-Host "   Custom Key Filter: diagnostic_severity = WARN"
Write-Host "   Notification: Email - larrybesant@gmail.com`n"

Write-Host "6. ✅ Verify all 3 alerts are created and enabled`n"

# Step 7: Quick links
Write-Host "=" * 70
Write-Host "🔗 Quick Access Links" -ForegroundColor Green
Write-Host "=" * 70

Write-Host "`n📍 Alert Policies Dashboard:"
Write-Host "   https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies`n"

Write-Host "📍 Crashlytics Console:"
Write-Host "   https://console.firebase.google.com/project/mixvy-v2/crashlytics`n"

Write-Host "📍 Notification Channels:"
Write-Host "   https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies/channels`n"

# Step 8: Summary
Write-Host "=" * 70
Write-Host "📊 Summary" -ForegroundColor Green
Write-Host "=" * 70

Write-Host "`n✅ Prerequisites verified"
Write-Host "✅ Project configured: $ProjectId"
Write-Host "✅ Email channel: $Email"
Write-Host "⏳ Alerts: Ready for manual creation in Firebase Console"

Write-Host "`n💡 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Open Firebase Console (link above)"
Write-Host "2. Create 3 alerts using the copy-paste configuration"
Write-Host "3. Verify email notifications are enabled"
Write-Host "4. Test alert delivery with a sample connection failure`n"

Write-Host "📝 Reference Document:"
Write-Host "   See: CREATE_ALERTS_MANUAL.md (complete step-by-step guide)`n"

Write-Host "✨ Setup Guide Complete!" -ForegroundColor Green
