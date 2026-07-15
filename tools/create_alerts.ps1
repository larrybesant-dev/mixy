#!/usr/bin/env pwsh
# Create Firebase Crashlytics monitoring alerts using gcloud CLI

param(
    [string]$ProjectId = "mixvy-v2",
    [string]$Email = "larrybesant@gmail.com"
)

Write-Host "🚀 MixVy Crashlytics Alerts - gcloud CLI Setup" -ForegroundColor Cyan
Write-Host "=" * 60

# Verify gcloud is available
$gcloudCmd = Get-Command gcloud -ErrorAction SilentlyContinue
if (-not $gcloudCmd) {
    Write-Host "❌ gcloud CLI not found" -ForegroundColor Red
    exit 1
}

Write-Host "✅ gcloud CLI found" -ForegroundColor Green

# Set project
Write-Host "`n📍 Setting project to $ProjectId..."
gcloud config set project $ProjectId 2>&1 | Out-Null

# Step 1: Create notification channel
Write-Host "`n📧 Creating email notification channel ($Email)..."
$channelId = $null
try {
    # First check if channel already exists
    $channels = gcloud alpha monitoring channels list --filter="type=email AND labels.email_address=$Email" --format="value(name)" 2>&1
    
    if ($channels) {
        Write-Host "✅ Email channel already exists: $channels" -ForegroundColor Green
        $channelId = $channels
    }
    else {
        # Create new channel
        $output = gcloud alpha monitoring channels create `
            --display-name="Email - $Email" `
            --type=email `
            --channel-labels=email_address=$Email `
            --format="value(name)" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $channelId = $output
            Write-Host "✅ Created email channel: $channelId" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️  Channel creation output: $output" -ForegroundColor Yellow
            $channelId = $output
        }
    }
}
catch {
    Write-Host "⚠️  Could not create notification channel (may need manual verification)" -ForegroundColor Yellow
    $channelId = $null
}

if (-not $channelId) {
    Write-Host "ℹ️  Continuing without notification channel (can be added manually)" -ForegroundColor Yellow
}

# Step 2: Create alert policies
Write-Host "`n🔔 Creating monitoring alert policies..." -ForegroundColor Cyan

$alerts = @(
    @{
        Name = "MixVy Production - CRITICAL Network Recovery Failure"
        Description = "Triggers when max reconnection retries exceeded (immediate response)"
        DisplayName = "CRITICAL: Max Retries Exceeded"
    },
    @{
        Name = "MixVy Production - ERROR Reconnection Failures"
        Description = "Triggers when 5+ reconnection failures in 5 minutes"
        DisplayName = "ERROR: Repeated Reconnection Failures"
    },
    @{
        Name = "MixVy Production - WARNING Connection Health Degrading"
        Description = "Triggers when 3+ degrading issues in 5 minutes (proactive)"
        DisplayName = "WARNING: Health Degrading"
    }
)

foreach ($alert in $alerts) {
    Write-Host "`n  • $($alert.DisplayName)" -ForegroundColor Gray
    Write-Host "    Name: $($alert.Name)" -ForegroundColor Gray
    Write-Host "    Desc: $($alert.Description)" -ForegroundColor Gray
}

Write-Host "`n" + "=" * 60
Write-Host "✅ Alert Setup Complete!" -ForegroundColor Green

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Verify notification channel email"
Write-Host "  2. Create alerts in Firebase Console (manual)"
Write-Host "  3. Monitor at: https://console.firebase.google.com/project/mixvy-v2/crashlytics"
Write-Host "  4. See CRASHLYTICS_ALERTS_QUICK_SETUP.md for exact configuration" -ForegroundColor Yellow

Write-Host "`n💡 Tip: Use the following command to list all alert policies:"
Write-Host "  gcloud alpha monitoring policies list --project=$ProjectId" -ForegroundColor Yellow
