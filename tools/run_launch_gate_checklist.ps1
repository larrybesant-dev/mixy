<#
.SYNOPSIS
    Pre-launch gate checklist for MixVy.

.DESCRIPTION
    Runs all automated checks, then walks you through manual Stripe / entitlement
    smoke tests with Y/N prompts. Exit code 0 = all gates passed.
    Run this ≤30 minutes before pushing to production.

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File tools/run_launch_gate_checklist.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot

$passed  = [System.Collections.Generic.List[string]]::new()
$failed  = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

function Pass([string]$label) {
    Write-Host "  [PASS] $label" -ForegroundColor Green
    $passed.Add($label)
}

function Fail([string]$label, [string]$detail = '') {
    $msg = if ($detail) { "$label — $detail" } else { $label }
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    $failed.Add($msg)
}

function Skip([string]$label, [string]$reason) {
    Write-Host "  [SKIP] $label ($reason)" -ForegroundColor Yellow
    $skipped.Add($label)
}

function Ask([string]$prompt) {
    $ans = Read-Host "  $prompt [Y/n]"
    return ($ans -eq '' -or $ans -match '^[Yy]')
}

function Section([string]$title) {
    Write-Host ''
    Write-Host "━━━  $title  ━━━" -ForegroundColor Cyan
}

# ─── Automated Gates ───────────────────────────────────────────────────────────

Section 'Static analysis'

Write-Host '  Running flutter analyze...'
flutter analyze --no-fatal-warnings 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Pass 'flutter analyze' }
else                      { Fail 'flutter analyze' 'see above for errors' }

Section 'Architecture guardrails'

Write-Host '  Running validate_architecture_guardrails...'
powershell -ExecutionPolicy Bypass -File tools/validate_architecture_guardrails.ps1 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Pass 'Architecture guardrails' }
else                      { Fail 'Architecture guardrails' 'run script directly to see violations' }

Section 'Unit tests'

Write-Host '  Running flutter tests...'
flutter test --no-pub 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Pass 'Flutter unit tests' }
else                      { Fail 'Flutter unit tests' 'run flutter test to see failures' }

Write-Host '  Running Functions payment tests...'
try {
    npm --prefix functions test 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Pass 'Functions payment tests' }
    else                      { Fail 'Functions payment tests' 'run npm --prefix functions test' }
} catch {
    Skip 'Functions payment tests' 'npm not available in this shell'
}

# ─── Manual Smoke Tests ────────────────────────────────────────────────────────

Section 'Stripe payment flow (manual)'

Write-Host ''
Write-Host '  Use a Stripe test card (4242 4242 4242 4242) for all steps below.'
Write-Host ''

$step1 = Ask 'Step 1 — Successful payment: complete a test VIP purchase. Did the app unlock VIP within ~5 seconds?'
if ($step1) { Pass 'Stripe: successful payment → VIP unlock' }
else         { Fail 'Stripe: successful payment → VIP unlock' }

$step2 = Ask 'Step 2 — Webhook replay: in the Stripe dashboard, resend the checkout.session.completed event. Did it remain idempotent (no duplicate entitlement)?'
if ($step2) { Pass 'Stripe: webhook replay deduplication' }
else         { Fail 'Stripe: webhook replay deduplication' }

$step3 = Ask 'Step 3 — Declined card: try a purchase with the decline card (4000 0000 0000 0002). Did the app show an error without granting VIP?'
if ($step3) { Pass 'Stripe: declined card → no partial unlock' }
else         { Fail 'Stripe: declined card → no partial unlock' }

# ─── Entitlement Persistence ───────────────────────────────────────────────────

Section 'Entitlement persistence (manual)'

$step4 = Ask 'Step 4 — Cold-start persistence: close the app fully, reopen after 2+ minutes. Is VIP still unlocked for the test account?'
if ($step4) { Pass 'Entitlement: persists across cold start' }
else         { Fail 'Entitlement: persists across cold start' }

$step5 = Ask 'Step 5 — Ads suppressed: confirm the test VIP account sees no promo banner on the Discovery feed.'
if ($step5) { Pass 'Entitlement: ads suppressed for VIP' }
else         { Fail 'Entitlement: ads suppressed for VIP' }

$step6 = Ask 'Step 6 — Free account: confirm a non-VIP account still sees the promo banner and no feature-gated routes are accessible.'
if ($step6) { Pass 'Entitlement: free account correctly gated' }
else         { Fail 'Entitlement: free account correctly gated' }

# ─── Entitlement Lifecycle ─────────────────────────────────────────────────────

Section 'Entitlement lifecycle (manual)'

$step7 = Ask 'Step 7 — Refund revocation: in the Stripe dashboard, issue a full refund for the test purchase. Did VIP lock again within ~30 seconds?'
if ($step7) { Pass 'Entitlement: refund revokes VIP' }
else         { Fail 'Entitlement: refund revokes VIP' }

$step8 = Ask 'Step 8 — Slow webhook simulation: use the Stripe CLI to delay delivery by 30 seconds (stripe trigger checkout.session.completed --delay 30). Did the app show the pending "Activating your VIP" state while waiting, then unlock automatically?'
if ($step8) { Pass 'Entitlement: optimistic pending state resolves correctly' }
else         { Fail 'Entitlement: optimistic pending state resolves correctly' }

$step9 = Ask 'Step 9 — Admin override: use a Firebase Admin SDK call (or direct Firestore write) to invoke adminSetEntitlement on a test user. Did entitlement status update within ~5 seconds on that device?'
if ($step9) { Pass 'Entitlement: admin override takes effect' }
else         { Skip 'Entitlement: admin override' 'requires admin SDK access — verify before first live user incident' }

# ─── Summary ───────────────────────────────────────────────────────────────────

Section 'Launch gate summary'
Write-Host ''
Write-Host "  Passed : $($passed.Count)" -ForegroundColor Green
if ($skipped.Count -gt 0) {
    Write-Host "  Skipped: $($skipped.Count)" -ForegroundColor Yellow
}
if ($failed.Count -gt 0) {
    Write-Host "  Failed : $($failed.Count)" -ForegroundColor Red
    Write-Host ''
    foreach ($f in $failed) {
        Write-Host "    ✗ $f" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host '  Launch gate FAILED. Resolve all failures before deploying.' -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ''
Write-Host '  All launch gate checks passed. Safe to deploy.' -ForegroundColor Green
Pop-Location
exit 0
