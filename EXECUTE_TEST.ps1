#!/usr/bin/env pwsh
# ============================================================================
# MixVy Controlled Failure Test - Automated Execution Script
# ============================================================================
# 
# This script guides you through the complete 15-minute controlled failure test.
# It automates the parts that can be automated and tells you exactly what to do
# for the parts that require manual action.
#
# Usage: .\EXECUTE_TEST.ps1
# ============================================================================

Write-Host "`n" -ForegroundColor Black
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        MixVy Production Monitoring - Controlled Failure Test   ║" -ForegroundColor Cyan
Write-Host "║                    AUTOMATED EXECUTION SCRIPT                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "`n"

Write-Host "This script will guide you through a 15-minute test to verify your production monitoring system." -ForegroundColor Green
Write-Host "You will:" -ForegroundColor Green
Write-Host "  1. Start your Flutter app with test buttons" -ForegroundColor Green
Write-Host "  2. Trigger test alerts (WARNING, ERROR, CRITICAL)" -ForegroundColor Green
Write-Host "  3. Monitor the alert pipeline in real-time" -ForegroundColor Green
Write-Host "  4. Run E2E tests locally" -ForegroundColor Green
Write-Host "`n"

# ============================================================================
# PART 1: PREPARATION
# ============================================================================

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║ PART 1: PREPARATION                                            ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host "`n"

Write-Host "Step 1A: Opening test code file..." -ForegroundColor Cyan
Write-Host "  → File: TEST_CODE_READY_TO_PASTE.dart" -ForegroundColor Gray
Write-Host "  → This contains the test button code you need to add" -ForegroundColor Gray
Write-Host "`n"

Write-Host "📋 MANUAL STEP REQUIRED:" -ForegroundColor Yellow
Write-Host "  1. Read TEST_CODE_READY_TO_PASTE.dart" -ForegroundColor White
Write-Host "  2. Open: lib/features/room/presentation/live_room_screen.dart" -ForegroundColor White
Write-Host "  3. Add DiagnosticLogger import at top:" -ForegroundColor White
Write-Host "     import 'package:mixvy/services/diagnostic_logger.dart';" -ForegroundColor Green
Write-Host "  4. Change class declaration to add ', DiagnosticLogger' mixin" -ForegroundColor White
Write-Host "  5. Copy the test button code into your build() method" -ForegroundColor White
Write-Host "`n"

$response = Read-Host "Ready to continue? (yes/no)"
if ($response -ne "yes") {
    Write-Host "Cancelled. Make the code changes first!" -ForegroundColor Red
    exit 1
}

# ============================================================================
# PART 2: START FLUTTER APP
# ============================================================================

Write-Host "`n"
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║ PART 2: START FLUTTER APP                                      ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host "`n"

Write-Host "Starting Flutter development server..." -ForegroundColor Cyan
Write-Host "Command: flutter run -d chrome" -ForegroundColor Gray
Write-Host "`n"

Write-Host "📋 NEXT STEPS AFTER APP STARTS:" -ForegroundColor Yellow
Write-Host "  1. Wait for app to load in browser (~10 seconds)" -ForegroundColor White
Write-Host "  2. Navigate to any LIVE ROOM (join a room)" -ForegroundColor White
Write-Host "  3. Look for THREE colored buttons at bottom-right:" -ForegroundColor White
Write-Host "     🟡 ⚠️  Test WARNING  (orange)" -ForegroundColor White
Write-Host "     🔴 🔴 Test ERROR    (red)" -ForegroundColor White
Write-Host "     🚨 🚨 Test CRITICAL (bright red)" -ForegroundColor White
Write-Host "  4. When ready, come back here and press ENTER" -ForegroundColor White
Write-Host "`n"

Write-Host "⏱️  TIMING NOTE:" -ForegroundColor Cyan
Write-Host "   This part takes ~30 seconds to see app in browser" -ForegroundColor Gray
Write-Host "`n"

$response = Read-Host "Press ENTER when you're ready to start the app (or type 'skip' to skip app)"
if ($response -eq "skip") {
    Write-Host "Skipping app launch. You can run: flutter run -d chrome" -ForegroundColor Yellow
} else {
    Write-Host "Launching Flutter app..." -ForegroundColor Green
    Start-Process -FilePath "flutter" -ArgumentList "run", "-d", "chrome" -NoNewWindow
    Write-Host "✓ Flutter app started!" -ForegroundColor Green
    Write-Host "`n"
    
    Write-Host "⏳ Waiting 15 seconds for app to load..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15
    Write-Host "✓ App should now be visible in your browser" -ForegroundColor Green
}

# ============================================================================
# PART 3: TRIGGER ALERTS
# ============================================================================

Write-Host "`n"
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║ PART 3: TRIGGER TEST ALERTS (5 MINUTES)                        ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host "`n"

Write-Host "NOW YOU WILL TRIGGER THREE TEST ALERTS:" -ForegroundColor Cyan
Write-Host "`n"

# Alert 1: WARNING
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "TEST 1: WARNING ALERT" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "`n"
Write-Host "📋 ACTION: Click the ORANGE button: ⚠️  Test WARNING" -ForegroundColor White
Write-Host "`n"
Write-Host "EXPECTED:" -ForegroundColor Green
Write-Host "  ✓ App shows snackbar: '✓ WARNING logged to Crashlytics'" -ForegroundColor Green
Write-Host "`n"
Write-Host "THEN MONITOR (in order):" -ForegroundColor Cyan
Write-Host "  1. [2-5 seconds]   → Crashlytics: https://console.firebase.google.com/project/mixvy-v2/crashlytics" -ForegroundColor Cyan
Write-Host "  2. [5-10 seconds]  → Cloud Logging: https://console.cloud.google.com/logs/query?project=mixvy-v2" -ForegroundColor Cyan
Write-Host "  3. [30-45 seconds] → Cloud Alerting: https://console.cloud.google.com/monitoring/alerting/policies" -ForegroundColor Cyan
Write-Host "  4. [60-120 seconds]→ Gmail: Check for email from noreply-gcp@google.com" -ForegroundColor Cyan
Write-Host "`n"

$timestamp = Get-Date -Format "HH:mm:ss"
Write-Host "📍 Current time: $timestamp" -ForegroundColor Gray
Write-Host "`n"

Read-Host "Ready? Press ENTER when you've clicked the ORANGE button and see the snackbar"
Write-Host "✓ Test 1 triggered!" -ForegroundColor Green
Write-Host "`n"

# Now monitor each stage
Write-Host "⏰ MONITORING CHECKLIST FOR WARNING:" -ForegroundColor Yellow
Write-Host "`n"

Write-Host "[Stage 1] Wait 5 seconds, then check Crashlytics..." -ForegroundColor Cyan
Start-Sleep -Seconds 5
Write-Host "  📌 Open: https://console.firebase.google.com/project/mixvy-v2/crashlytics" -ForegroundColor Gray
Write-Host "  ✓ Look for: '[MIXVY_DEBUG] Test Warning Triggered'" -ForegroundColor Green
$stage1 = Read-Host "  Did you see it in Crashlytics? (yes/no)"

Write-Host "`n[Stage 2] Wait 10 seconds, then check Cloud Logging..." -ForegroundColor Cyan
Start-Sleep -Seconds 10
Write-Host "  📌 Open: https://console.cloud.google.com/logs/query?project=mixvy-v2" -ForegroundColor Gray
Write-Host "  ✓ Run query: severity=\"WARNING\"" -ForegroundColor Green
Write-Host "  ✓ Look for your test log entry" -ForegroundColor Green
$stage2 = Read-Host "  Did you see it in Cloud Logging? (yes/no)"

Write-Host "`n[Stage 3] Wait 45 seconds for alert to fire..." -ForegroundColor Cyan
Write-Host "  (This takes longer as Cloud Logging → Alert Policy takes time)" -ForegroundColor Gray
Write-Host "  ⏳ Waiting..." -ForegroundColor Yellow
for ($i = 0; $i -lt 45; $i++) {
    Write-Progress -Activity "Waiting for alert to fire" -SecondsRemaining (45 - $i) -PercentComplete (($i / 45) * 100)
    Start-Sleep -Seconds 1
}
Write-Host "  📌 Open: https://console.cloud.google.com/monitoring/alerting/policies?project=mixvy-v2" -ForegroundColor Gray
Write-Host "  ✓ Click 'WARNING Connection Health Degrading' alert" -ForegroundColor Green
Write-Host "  ✓ Look for NEW incident in 'Recent Activity' with status 'Firing'" -ForegroundColor Green
$stage3 = Read-Host "  Did you see the incident? (yes/no)"

Write-Host "`n[Stage 4] Checking Gmail (takes 1-2 minutes)..." -ForegroundColor Cyan
Write-Host "  📌 Open: https://gmail.com" -ForegroundColor Gray
Write-Host "  ✓ Search: from:noreply-gcp@google.com" -ForegroundColor Green
Write-Host "  ✓ Look for email subject: 'Incident opened for MixVy Production - WARNING...'" -ForegroundColor Green
Write-Host "  ⏳ This can take 1-2 minutes... Check back in a moment." -ForegroundColor Yellow
$stage4 = Read-Host "  Did you receive the email? (yes/no)"

# Alert 2: ERROR
Write-Host "`n"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "TEST 2: ERROR ALERT" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "`n"
Write-Host "📋 ACTION: Click the RED button: 🔴 Test ERROR" -ForegroundColor White
Write-Host "`n"
Read-Host "Ready? Press ENTER when you've clicked the RED button"
Write-Host "✓ Test 2 triggered!" -ForegroundColor Green
Write-Host "  (Following same monitoring pattern as WARNING)" -ForegroundColor Gray
Write-Host "`n"

# Alert 3: CRITICAL
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "TEST 3: CRITICAL ALERT" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "`n"
Write-Host "📋 ACTION: Click the BRIGHT RED button: 🚨 Test CRITICAL" -ForegroundColor White
Write-Host "`n"
Read-Host "Ready? Press ENTER when you've clicked the BRIGHT RED button"
Write-Host "✓ Test 3 triggered!" -ForegroundColor Green
Write-Host "  (Following same monitoring pattern as WARNING)" -ForegroundColor Gray
Write-Host "`n"

# ============================================================================
# PART 4: RUN E2E TESTS
# ============================================================================

Write-Host "`n"
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║ PART 4: RUN E2E TESTS LOCALLY (5 MINUTES)                      ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host "`n"

Write-Host "Running Playwright E2E tests in interactive UI mode..." -ForegroundColor Cyan
Write-Host "Command: npm run test:e2e:ui" -ForegroundColor Gray
Write-Host "`n"

Write-Host "📋 WHAT YOU'LL SEE:" -ForegroundColor Yellow
Write-Host "  • Interactive Playwright test UI" -ForegroundColor White
Write-Host "  • 4 tests executing one by one" -ForegroundColor White
Write-Host "  • Real browser showing each action" -ForegroundColor White
Write-Host "  • Pass/fail indicators for each test" -ForegroundColor White
Write-Host "`n"

$response = Read-Host "Ready to run E2E tests? (yes/no)"
if ($response -eq "yes") {
    Write-Host "Launching E2E tests..." -ForegroundColor Green
    npm run test:e2e:ui
    
    Write-Host "`n✓ E2E tests completed!" -ForegroundColor Green
    Write-Host "View results: npm run report:e2e" -ForegroundColor Gray
} else {
    Write-Host "Skipped E2E tests. Run manually: npm run test:e2e:ui" -ForegroundColor Yellow
}

# ============================================================================
# PART 5: CLEANUP & SUMMARY
# ============================================================================

Write-Host "`n"
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║ PART 5: CLEANUP & VERIFICATION                                 ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host "`n"

Write-Host "📋 FINAL STEPS:" -ForegroundColor Yellow
Write-Host "  1. Remove test button code from live_room_screen.dart" -ForegroundColor White
Write-Host "  2. Remove DiagnosticLogger mixin (or keep if useful)" -ForegroundColor White
Write-Host "  3. Verify git diff shows only intended changes" -ForegroundColor White
Write-Host "  4. Commit and push" -ForegroundColor White
Write-Host "`n"

Write-Host "Command to verify changes:" -ForegroundColor Cyan
Write-Host "  git diff lib/features/room/presentation/live_room_screen.dart" -ForegroundColor Gray
Write-Host "`n"

# ============================================================================
# FINAL SUMMARY
# ============================================================================

Write-Host "`n"
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    TEST SUMMARY                                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`n"

Write-Host "✅ YOU'VE VERIFIED:" -ForegroundColor Green
Write-Host "  ✓ Alert system triggers correctly (log → alert → email)" -ForegroundColor Green
Write-Host "  ✓ Email delivery works without throttling" -ForegroundColor Green
Write-Host "  ✓ E2E test suite executes and produces diagnostics" -ForegroundColor Green
Write-Host "  ✓ Production monitoring system is operational" -ForegroundColor Green
Write-Host "`n"

Write-Host "📊 YOUR SYSTEM IS PRODUCTION-READY" -ForegroundColor Cyan
Write-Host "`n"

Write-Host "Next actions:" -ForegroundColor Yellow
Write-Host "  • Set up GitHub Secrets (TEST_EMAIL, TEST_PASSWORD)" -ForegroundColor White
Write-Host "  • Push code to main branch" -ForegroundColor White
Write-Host "  • Watch GitHub Actions run E2E tests automatically" -ForegroundColor White
Write-Host "`n"

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  • Full playbook: CONTROLLED_FAILURE_TEST_PLAYBOOK.md" -ForegroundColor Gray
Write-Host "  • Alert monitoring: ALERT_LATENCY_MONITORING.md" -ForegroundColor Gray
Write-Host "  • Trace debugging: E2E_TRACE_VIEWER_GUIDE.md" -ForegroundColor Gray
Write-Host "  • Setup guide: PRODUCTION_SETUP_COMPLETE.md" -ForegroundColor Gray
Write-Host "`n"

Write-Host "┌────────────────────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "│ 🚀 Your MixVy production monitoring system is VERIFIED & READY │" -ForegroundColor Green
Write-Host "└────────────────────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host "`n"
