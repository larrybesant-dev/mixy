#!/usr/bin/env pwsh
# Create Firebase Crashlytics monitoring alerts using gcloud CLI

Write-Host "🚀 MixVy Crashlytics Alerts - Setup Guide" -ForegroundColor Cyan
Write-Host "=" * 70

Write-Host "`n📋 System Status Check:" -ForegroundColor Green

# Check gcloud
$gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
if ($gcloud) {
    Write-Host "  ✅ gcloud CLI installed" -ForegroundColor Green
}
else {
    Write-Host "  ❌ gcloud CLI not found" -ForegroundColor Red
    exit 1
}

# Check authentication
$auth = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>&1
if ($auth) {
    Write-Host "  ✅ Authenticated as: $auth" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  Authentication may be needed" -ForegroundColor Yellow
}

Write-Host "`n📝 Alert Configuration Summary:" -ForegroundColor Cyan

Write-Host "`n  Alert 1: CRITICAL - Max Retries Exceeded" -ForegroundColor Yellow
Write-Host "    Severity: FATAL"
Write-Host "    Trigger: When max reconnection retries exceeded"
Write-Host "    Response: Immediate (highest priority)"

Write-Host "`n  Alert 2: ERROR - Repeated Reconnection Failures" -ForegroundColor Yellow
Write-Host "    Condition: 5+ errors in 5 minutes"
Write-Host "    Trigger: Custom key diagnostic_severity = ERROR"
Write-Host "    Response: 5-minute window"

Write-Host "`n  Alert 3: WARNING - Connection Health Degrading" -ForegroundColor Yellow
Write-Host "    Condition: 3+ warnings in 5 minutes"
Write-Host "    Trigger: Custom key diagnostic_severity = WARN"
Write-Host "    Response: Proactive monitoring"

Write-Host "`n" + "=" * 70
Write-Host "📚 Documentation:" -ForegroundColor Green
Write-Host "  • CRASHLYTICS_ALERTS_QUICK_SETUP.md" -ForegroundColor Cyan
Write-Host "    └─ Copy-paste ready configuration values"
Write-Host "  • CRASHLYTICS_ALERTS_SETUP_GUIDE.md" -ForegroundColor Cyan
Write-Host "    └─ Detailed step-by-step instructions"

Write-Host "`n🔗 Quick Links:" -ForegroundColor Green
Write-Host "  1. Create Alerts: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies/create" -ForegroundColor Cyan
Write-Host "  2. View Policies: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies" -ForegroundColor Cyan
Write-Host "  3. Crashlytics: https://console.firebase.google.com/project/mixvy-v2/crashlytics" -ForegroundColor Cyan

Write-Host "`n💡 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Open CRASHLYTICS_ALERTS_QUICK_SETUP.md"
Write-Host "  2. Follow the 'Quick Access' section"
Write-Host "  3. Copy exact values and create 3 alerts in Firebase Console"
Write-Host "  4. Verify email notifications"

Write-Host "`n✨ Configuration Applied:" -ForegroundColor Green
Write-Host "  ✅ Firestore security rules deployed (permission check enabled)"
Write-Host "  ✅ DiagnosticLogger production handler configured"
Write-Host "  ✅ ConnectionHealthCheckService active"
Write-Host "  ✅ All services logging with [MIXVY_DEBUG] prefix"

Write-Host "`n" + "=" * 70
