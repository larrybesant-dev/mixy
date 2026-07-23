param(
  [switch]$StopOnFailure,
  [switch]$SkipWebBuild,
  [ValidateSet('observe', 'enforce')]
  [string]$ValidationMode = 'enforce',
  [string]$ReportsDir = 'tools/reports'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

if (-not (Test-Path $ReportsDir)) {
  New-Item -Path $ReportsDir -ItemType Directory | Out-Null
}

function Get-FailureBucket {
  param(
    [object]$Run
  )

  $signal = "$(($Run.caseId)) $(($Run.caseName)) $(($Run.category)) $(($Run.failureClass)) $(($Run.command)) $(($Run.negativeMatches -join ' '))".ToLowerInvariant()
  $exitCode = [int]$Run.exitCode

  if ($exitCode -in @(124, 130, 137, 143) -or $signal -match 'timeout|timed out|cancelled|killed|infra|network|econn|socket|dns|service unavailable|resource exhausted') {
    return 'TIMEOUT / INFRA FAILURE'
  }
  if ($signal -match 'payment|stripe|checkout|coin|webhook|idempotency|double_debit|double_credit|lh-py-|py-') {
    return 'PAYMENT FAILURE'
  }
  if ($signal -match 'rules|firestore|security enforcement|emulator|rule' -or $Run.caseId -match '^(LH-RL-|RL-)') {
    return 'RULES FAILURE'
  }
  if ($signal -match 'room|presence|host|mic|speaker|live|reconnect|participant|slot|rs-|ps-|lh-rm-') {
    return 'ROOM FAILURE'
  }
  return 'TIMEOUT / INFRA FAILURE'
}

$cases = @(
  [ordered]@{
    Id = 'RS-1'
    Name = 'Reconnect Storm'
    Category = 'System Stability'
    FailureClass = 'ghost_leave|duplicate_join|reconnect_loop'
    Command = 'flutter test --no-pub test/room_session_stress_test.dart'
    PassCriteria = 'No reconnect chaos regression; stress suite must pass end-to-end.'
    PositivePatterns = @('room_session_stress_test.dart', 'stress simulates room churn without duplicates or presence drift')
    NegativePatterns = @('Some tests failed', 'Failed to load', 'Unhandled exception')
  },
  [ordered]@{
    Id = 'RS-2'
    Name = 'Listener Leak Verification'
    Category = 'Infrastructure Health'
    FailureClass = 'listener_leak|duplicate_streams'
    Command = 'flutter test --no-pub test/room_chaos_master_test.dart'
    PassCriteria = 'No duplicate listener drift or leak regressions; chaos suite must pass.'
    PositivePatterns = @('room_chaos_master_test.dart', 'same user joining from two controllers remains deduped')
    NegativePatterns = @('Some tests failed', 'Failed to load', 'Unhandled exception')
  },
  [ordered]@{
    Id = 'RS-3'
    Name = 'Host Authority Stress'
    Category = 'Authority Correctness'
    FailureClass = 'split_brain|host_missing'
    Command = 'flutter test --no-pub test/room_state_machine_test.dart'
    PassCriteria = 'Host count must converge deterministically and authority tests must pass.'
    PositivePatterns = @('room_state_machine_test.dart', 'ignores stale host claims after migration to a new host')
    NegativePatterns = @('Some tests failed', 'Failed to load', 'Unhandled exception')
  },
  [ordered]@{
    Id = 'RS-4'
    Name = 'Mic Pressure Test'
    Category = 'Realtime Consistency'
    FailureClass = 'mic_desync|speaker_overflow'
    Command = 'flutter test --no-pub test/room_slot_service_test.dart test/room_host_control_panel_stage_tab_test.dart'
    PassCriteria = 'Mic grants, revokes, and slot limits stay aligned under pressure.'
    PositivePatterns = @('room_slot_service_test.dart', 'room_host_control_panel_stage_tab_test.dart')
    NegativePatterns = @('Some tests failed', 'Failed to load', 'Unhandled exception')
  },
  [ordered]@{
    Id = 'RS-5'
    Name = 'Late Join Sync'
    Category = 'Realtime Consistency'
    FailureClass = 'late_join_sync|ui_desync'
    Command = 'flutter test --no-pub test/live_room_screen_test.dart test/room_state_test.dart'
    PassCriteria = 'Late-join hydration and UI authority sync must pass.'
    PositivePatterns = @('live_room_screen_test.dart', 'room_state_test.dart')
    NegativePatterns = @('Some tests failed', 'Failed to load', 'Unhandled exception')
  },
  [ordered]@{
    Id = 'RS-6'
    Name = 'Telemetry Truth Validation'
    Category = 'Observability'
    FailureClass = 'false_positive|silent_failure|bad_alerting'
    Command = 'flutter test --no-pub test/app_telemetry_test.dart'
    PassCriteria = 'Health alerts and suppression model must match deterministic telemetry tests.'
    PositivePatterns = @('app_telemetry_test.dart', 'All tests passed!')
    NegativePatterns = @('Some tests failed', 'Failed to load', 'Unhandled exception')
  }
)

if (-not $SkipWebBuild) {
  $cases += [ordered]@{
    Id = 'RS-7'
    Name = 'Recovery Baseline Build'
    Category = 'Recovery Validation'
    FailureClass = 'build_regression|residual_state_contamination'
    Command = 'flutter build web --release --base-href /'
    PassCriteria = 'Fresh production web build succeeds after room gate execution.'
    PositivePatterns = @('Built build\\web', 'Wasm dry run succeeded')
    NegativePatterns = @('Build failed', 'Failed to compile application for the Web.', 'Unhandled exception')
  }
}

function Invoke-GateCase {
  param(
    [hashtable]$Case
  )

  $startedAt = Get-Date
  $captured = @()

  Write-Host ''
  Write-Host "========== $($Case.Id) $($Case.Name) ==========" -ForegroundColor Yellow
  Write-Host "Category: $($Case.Category)"
  Write-Host "FailureClass: $($Case.FailureClass)"
  Write-Host "PassCriteria: $($Case.PassCriteria)"
  Write-Host "Command: $($Case.Command)" -ForegroundColor Cyan

  try {
    $captured = @(cmd.exe /d /s /c "$($Case.Command) 2>&1")
    $exitCode = $LASTEXITCODE
  } catch {
    $captured += $_ | Out-String
    $exitCode = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 1 }
  }

  $endedAt = Get-Date
  $durationMs = [int][Math]::Round(($endedAt - $startedAt).TotalMilliseconds)
  $outputText = ($captured | Out-String)

  if (-not [string]::IsNullOrWhiteSpace($outputText)) {
    $outputText | Out-Host
  }

  $positiveMatches = @()
  foreach ($pattern in @($Case.PositivePatterns)) {
    if ($outputText -match [regex]::Escape($pattern)) {
      $positiveMatches += $pattern
    }
  }

  $negativeMatches = @()
  foreach ($pattern in @($Case.NegativePatterns)) {
    if ($outputText -match [regex]::Escape($pattern)) {
      $negativeMatches += $pattern
    }
  }

  $signalPass = ($Case.PositivePatterns.Count -eq 0 -or $positiveMatches.Count -gt 0)
  $passed = ($exitCode -eq 0 -and $signalPass -and $negativeMatches.Count -eq 0)

  return [PSCustomObject]@{
    caseId = $Case.Id
    caseName = $Case.Name
    category = $Case.Category
    failureClass = $Case.FailureClass
    command = $Case.Command
    passCriteria = $Case.PassCriteria
    startedAtUtc = $startedAt.ToUniversalTime().ToString('o')
    endedAtUtc = $endedAt.ToUniversalTime().ToString('o')
    durationMs = $durationMs
    exitCode = $exitCode
    signalPass = $signalPass
    positiveMatches = $positiveMatches
    negativeMatches = $negativeMatches
    retryCount = 0
    passed = $passed
  }
}

$results = New-Object System.Collections.ArrayList
$failedCases = New-Object System.Collections.ArrayList

foreach ($case in $cases) {
  $result = Invoke-GateCase -Case $case
  [void]$results.Add($result)

  if (-not $result.passed) {
    [void]$failedCases.Add($result.caseId)
    Write-Host "FAIL: $($result.caseId)" -ForegroundColor Red
    if ($StopOnFailure) {
      break
    }
  } else {
    Write-Host "PASS: $($result.caseId)" -ForegroundColor Green
  }
}

$resultList = @($results)
$passedRuns = @($resultList | Where-Object { $_.passed }).Count
$failedRuns = @($resultList | Where-Object { -not $_.passed }).Count
$totalRuns = $resultList.Count
$verdict = if ($failedRuns -eq 0) { 'PASS' } else { 'FAIL' }

$failureCounts = [ordered]@{
  'ROOM FAILURE' = 0
  'PAYMENT FAILURE' = 0
  'RULES FAILURE' = 0
  'TIMEOUT / INFRA FAILURE' = 0
}

$failedResults = @($resultList | Where-Object { -not $_.passed })
$failedClassifications = @()
foreach ($failed in $failedResults) {
  $bucket = Get-FailureBucket -Run $failed
  $failureCounts[$bucket] = [int]$failureCounts[$bucket] + 1
  $failedClassifications += [PSCustomObject]@{
    caseId = $failed.caseId
    caseName = $failed.caseName
    failureBucket = $bucket
  }
}

$primaryFailureBucket = if ($failedResults.Count -eq 0) {
  'NONE'
} else {
  ($failureCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
}

$categorySummary = $resultList | Group-Object category | ForEach-Object {
  $runs = @($_.Group)
  [PSCustomObject]@{
    category = $_.Name
    total = $runs.Count
    passed = @($runs | Where-Object { $_.passed }).Count
    failed = @($runs | Where-Object { -not $_.passed }).Count
  }
}

$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$outputPath = Join-Path $ReportsDir "room_release_stress_gate_$timestamp.json"
$markdownPath = Join-Path $ReportsDir "room_release_stress_gate_$timestamp.md"

$report = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  validationMode = $ValidationMode
  releaseGate = 'room_release_stress_gate_v1'
  verdict = $verdict
  totalRuns = $totalRuns
  passedRuns = $passedRuns
  failedRuns = $failedRuns
  failedCaseIds = @($failedCases)
  failureClassificationSummary = [ordered]@{
    primaryFailureBucket = $primaryFailureBucket
    counts = [PSCustomObject]$failureCounts
    failedClassifications = @($failedClassifications)
  }
  categorySummary = @($categorySummary)
  cases = @($resultList)
}

$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding utf8

$lines = @(
  '# Room Release Stress Gate',
  '',
  "- GeneratedAtUtc: $($report.generatedAtUtc)",
  "- ValidationMode: $ValidationMode",
  "- Verdict: $verdict",
  "- TotalRuns: $totalRuns",
  "- PassedRuns: $passedRuns",
  "- FailedRuns: $failedRuns",
  "- PrimaryFailureBucket: $primaryFailureBucket",
  "- ROOM FAILURE: $($failureCounts.'ROOM FAILURE')",
  "- PAYMENT FAILURE: $($failureCounts.'PAYMENT FAILURE')",
  "- RULES FAILURE: $($failureCounts.'RULES FAILURE')",
  "- TIMEOUT / INFRA FAILURE: $($failureCounts.'TIMEOUT / INFRA FAILURE')",
  '',
  '| Case | Category | Result | DurationMs | Failure Class |',
  '| --- | --- | --- | ---: | --- |'
)

foreach ($item in $resultList) {
  $status = if ($item.passed) { 'PASS' } else { 'FAIL' }
  $lines += "| $($item.caseId) | $($item.category) | $status | $($item.durationMs) | $($item.failureClass) |"
}

$lines += ''
$lines += '## Gate Rule'
$lines += ''
$lines += '- PASS when every deterministic room case exits cleanly and produces expected signals.'
$lines += '- FAIL when any room chaos, authority, telemetry, or recovery case fails.'

$lines | Out-File -FilePath $markdownPath -Encoding utf8

Write-Host ''
Write-Host '========== Room Release Gate Summary ==========' -ForegroundColor Yellow
Write-Host "Verdict: $verdict"
Write-Host "Passed: $passedRuns / $totalRuns"
Write-Host "JSON report: $outputPath"
Write-Host "Markdown report: $markdownPath"

if ($failedRuns -gt 0 -and $ValidationMode -eq 'enforce') {
  exit 1
}

exit 0
