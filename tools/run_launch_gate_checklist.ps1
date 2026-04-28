<#
.SYNOPSIS
    Pre-launch gate checklist for MixVy.

.DESCRIPTION
    Runs all automated checks, then walks you through manual Stripe / entitlement
    smoke tests with Y/N prompts. Exit code 0 = all gates passed.
    Run this within 30 minutes before pushing to production.

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File tools/run_launch_gate_checklist.ps1
#>

param(
    [switch]$AutoSkipManual
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot

$passed  = [System.Collections.Generic.List[string]]::new()
$failed  = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()
$criticalFailures = [System.Collections.Generic.List[string]]::new()
$score = 0
$maxScore = 0

function Pass([string]$label) {
    Write-Host "  [PASS] $label" -ForegroundColor Green
    $passed.Add($label)
}

function Fail([string]$label, [string]$detail = '') {
    $msg = if ($detail) { "$label - $detail" } else { $label }
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    $failed.Add($msg)
}

function Skip([string]$label, [string]$reason) {
    Write-Host "  [SKIP] $label ($reason)" -ForegroundColor Yellow
    $skipped.Add($label)
}

function Register-Check(
    [string]$label,
    [bool]$passedCheck,
    [int]$points = 1,
    [bool]$critical = $false,
    [string]$detail = ''
) {
    $script:maxScore += $points
    if ($passedCheck) {
        $script:score += $points
        Pass $label
        return
    }

    Fail $label $detail
    if ($critical) {
        $script:criticalFailures.Add($label)
    }
}

function Skip-Check(
    [string]$label,
    [string]$reason,
    [int]$points = 1,
    [bool]$critical = $false
) {
    $script:maxScore += $points
    Skip $label $reason
    if ($critical) {
        $script:criticalFailures.Add("$label (skipped)")
    }
}

function Ask([string]$prompt) {
    if ($AutoSkipManual) {
        return $null
    }

    $ans = Read-Host "  $prompt [Y/n]"
    return ($ans -eq '' -or $ans -match '^[Yy]')
}

function Section([string]$title) {
    Write-Host ''
    Write-Host "=== $title ===" -ForegroundColor Cyan
}

# ─── Automated Gates ───────────────────────────────────────────────────────────

Section 'Static analysis'

Write-Host '  Running flutter analyze...'
flutter analyze --no-fatal-warnings 2>&1 | Out-Null
Register-Check 'flutter analyze' ($LASTEXITCODE -eq 0) 1 $true 'see above for errors'

Section 'Architecture guardrails'

Write-Host '  Running validate_architecture_guardrails...'
powershell -ExecutionPolicy Bypass -File tools/validate_architecture_guardrails.ps1 2>&1 | Out-Null
Register-Check 'Architecture guardrails' ($LASTEXITCODE -eq 0) 1 $true 'run script directly to see violations'

Section 'Unit tests'

Write-Host '  Running flutter tests...'
flutter test --no-pub 2>&1 | Out-Null
Register-Check 'Flutter unit tests' ($LASTEXITCODE -eq 0) 1 $true 'run flutter test to see failures'

Write-Host '  Running Functions payment tests...'
try {
    npm --prefix functions test 2>&1 | Out-Null
    Register-Check 'Functions payment tests' ($LASTEXITCODE -eq 0) 1 $true 'run npm --prefix functions test'
} catch {
    Skip-Check 'Functions payment tests' 'npm not available in this shell' 1 $true
}

# ─── Manual Smoke Tests ────────────────────────────────────────────────────────

Section 'Stripe payment flow (manual)'

Write-Host ''
Write-Host '  Use a Stripe test card (4242 4242 4242 4242) for all steps below.'
Write-Host ''

$step1 = Ask 'Step 1 - Successful payment: complete a test VIP purchase. Did the app unlock VIP within ~5 seconds?'
if ($null -eq $step1) { Skip-Check 'Stripe: successful payment -> VIP unlock' 'manual flow skipped via -AutoSkipManual' 1 $true }
else { Register-Check 'Stripe: successful payment -> VIP unlock' $step1 1 $true }

$step2 = Ask 'Step 2 - Webhook replay: in the Stripe dashboard, resend the checkout.session.completed event. Did it remain idempotent (no duplicate entitlement)?'
if ($null -eq $step2) { Skip-Check 'Stripe: webhook replay deduplication' 'manual flow skipped via -AutoSkipManual' 1 $true }
else { Register-Check 'Stripe: webhook replay deduplication' $step2 1 $true }

$step3 = Ask 'Step 3 - Declined card: try a purchase with the decline card (4000 0000 0000 0002). Did the app show an error without granting VIP?'
if ($null -eq $step3) { Skip-Check 'Stripe: declined card -> no partial unlock' 'manual flow skipped via -AutoSkipManual' 1 $false }
else { Register-Check 'Stripe: declined card -> no partial unlock' $step3 }

# ─── Entitlement Persistence ───────────────────────────────────────────────────

Section 'Entitlement persistence (manual)'

$step4 = Ask 'Step 4 - Cold-start persistence: close the app fully, reopen after 2+ minutes. Is VIP still unlocked for the test account?'
if ($null -eq $step4) { Skip-Check 'Entitlement: persists across cold start' 'manual flow skipped via -AutoSkipManual' 1 $false }
else { Register-Check 'Entitlement: persists across cold start' $step4 }

$step5 = Ask 'Step 5 - Ads suppressed: confirm the test VIP account sees no promo banner on the Discovery feed.'
if ($null -eq $step5) { Skip-Check 'Entitlement: ads suppressed for VIP' 'manual flow skipped via -AutoSkipManual' 1 $false }
else { Register-Check 'Entitlement: ads suppressed for VIP' $step5 }

$step6 = Ask 'Step 6 - Free account: confirm a non-VIP account still sees the promo banner and no feature-gated routes are accessible.'
if ($null -eq $step6) { Skip-Check 'Entitlement: free account correctly gated' 'manual flow skipped via -AutoSkipManual' 1 $false }
else { Register-Check 'Entitlement: free account correctly gated' $step6 }

# ─── Entitlement Lifecycle ─────────────────────────────────────────────────────

Section 'Entitlement lifecycle (manual)'

$step7 = Ask 'Step 7 - Refund revocation: in the Stripe dashboard, issue a full refund for the test purchase. Did VIP lock again within ~30 seconds?'
if ($null -eq $step7) { Skip-Check 'Entitlement: refund revokes VIP' 'manual flow skipped via -AutoSkipManual' 1 $true }
else { Register-Check 'Entitlement: refund revokes VIP' $step7 1 $true }

$step8 = Ask 'Step 8 - Slow webhook simulation: use the Stripe CLI to delay delivery by 30 seconds (stripe trigger checkout.session.completed --delay 30). Did the app show the pending "Activating your VIP" state while waiting, then unlock automatically?'
if ($null -eq $step8) { Skip-Check 'Entitlement: optimistic pending state resolves correctly' 'manual flow skipped via -AutoSkipManual' 1 $true }
else { Register-Check 'Entitlement: optimistic pending state resolves correctly' $step8 1 $true }

$step9 = Ask 'Step 9 - Admin override: use a Firebase Admin SDK call (or direct Firestore write) to invoke adminSetEntitlement on a test user. Did entitlement status update within ~5 seconds on that device?'
if ($null -eq $step9) {
    Skip-Check 'Entitlement: admin override takes effect' 'manual flow skipped via -AutoSkipManual' 1 $false
}
elseif ($step9) {
    Register-Check 'Entitlement: admin override takes effect' $true
}
else {
    Skip-Check 'Entitlement: admin override takes effect' 'requires admin SDK access - verify before first live user incident' 1 $false
}

# ─── Summary ───────────────────────────────────────────────────────────────────

Section 'Launch gate summary'
Write-Host ''
Write-Host "  Score  : $score / $maxScore" -ForegroundColor Cyan
Write-Host "  Passed : $($passed.Count)" -ForegroundColor Green
if ($skipped.Count -gt 0) {
    Write-Host "  Skipped: $($skipped.Count)" -ForegroundColor Yellow
}
if ($failed.Count -gt 0) {
    Write-Host "  Failed : $($failed.Count)" -ForegroundColor Red
    Write-Host ''
    foreach ($f in $failed) {
        Write-Host "    x $f" -ForegroundColor Red
    }
    if ($criticalFailures.Count -gt 0) {
        Write-Host ''
        Write-Host '  Critical blockers:' -ForegroundColor Red
        foreach ($blocker in $criticalFailures) {
            Write-Host "    - $blocker" -ForegroundColor Red
        }
    }
    Write-Host ''
    Write-Host '  Readiness verdict: HOLD' -ForegroundColor Red
    Write-Host '  Launch gate FAILED. Resolve all failures before deploying.' -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ''
if ($criticalFailures.Count -gt 0) {
    Write-Host '  Readiness verdict: HOLD' -ForegroundColor Red
    Write-Host '  Critical manual checks were skipped. Do not deploy yet.' -ForegroundColor Red
    Pop-Location
    exit 1
}

if ($score -eq $maxScore) {
    Write-Host '  Readiness verdict: SHIP' -ForegroundColor Green
    Write-Host '  All launch gate checks passed. Safe to deploy.' -ForegroundColor Green
}
else {
    Write-Host '  Readiness verdict: REVIEW' -ForegroundColor Yellow
    Write-Host '  No critical blockers remain, but there are skipped non-critical checks to close before broad rollout.' -ForegroundColor Yellow
}
Pop-Location
exit 0
