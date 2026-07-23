param(
  [int]$Cycles = 3,
  [int]$PressureRepeatsPerCycle = 1,
  [switch]$Shuffle,
  [switch]$StopOnFailure,
  [switch]$IncludeRulesValidation,
  [string]$ReportsDir = 'tools/reports',
  [ValidateSet('observe', 'enforce')]
  [string]$ValidationMode = 'enforce'
)

$ErrorActionPreference = 'Stop'

if ($Cycles -lt 1) {
  Write-Error 'Cycles must be >= 1'
  exit 1
}

if ($PressureRepeatsPerCycle -lt 0) {
  Write-Error 'PressureRepeatsPerCycle must be >= 0'
  exit 1
}

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

$baseCases = @(
  [ordered]@{
    Id = 'LH-RM-1'
    Name = 'Room Session Churn'
    Category = 'Room Concurrency'
    FailureClass = 'duplicate_join|presence_drift|participant_desync'
    Command = 'flutter test --no-pub test/room_session_stress_test.dart'
    PassCriteria = 'Room churn remains deduped with no presence drift.'
    PositivePatterns = @('stress simulates room churn without duplicates or presence drift', 'All tests passed!')
    NegativePatterns = @('Some tests failed', 'Unhandled exception', 'Failed to load')
  },
  [ordered]@{
    Id = 'LH-RM-2'
    Name = 'Room Chaos Authority'
    Category = 'Room Concurrency'
    FailureClass = 'host_split_brain|duplicate_controller_state'
    Command = 'flutter test --no-pub test/room_chaos_master_test.dart'
    PassCriteria = 'Authority and dedupe invariants hold across chaos cases.'
    PositivePatterns = @('room chaos master', 'All tests passed!')
    NegativePatterns = @('Some tests failed', 'Unhandled exception', 'Failed to load')
  },
  [ordered]@{
    Id = 'LH-PY-1'
    Name = 'Payment Replay Idempotency'
    Category = 'Payment Concurrency'
    FailureClass = 'double_debit|double_credit|idempotency_regression'
    Command = 'npm --prefix functions test -- --test-name-pattern "sendCoinTransferHandler deduplicates repeated idempotent calls|stripeWebhookHandler credits checkout.session.completed only once during replay"'
    PassCriteria = 'Replay and idempotent paths must remain one-write safe.'
    PositivePatterns = @('sendCoinTransferHandler deduplicates repeated idempotent calls', 'stripeWebhookHandler credits checkout.session.completed only once during replay')
    NegativePatterns = @('not ok ', 'ERR_TEST_FAILURE')
  },
  [ordered]@{
    Id = 'LH-PY-2'
    Name = 'Mic Callable Authority Under Pressure'
    Category = 'Room Concurrency'
    FailureClass = 'unauthorized_stage|mic_limit_regression|stale_stage_not_demoted'
    Command = 'npm --prefix functions test -- --test-name-pattern "grabMicHandler|inviteToMicHandler"'
    PassCriteria = 'Mic callable authority tests stay deterministic under repeated execution.'
    PositivePatterns = @('grabMicHandler', 'inviteToMicHandler')
    NegativePatterns = @('not ok ', 'ERR_TEST_FAILURE')
  },
  [ordered]@{
    Id = 'LH-PY-3'
    Name = 'Webhook Signature Rejection'
    Category = 'Payment Concurrency'
    FailureClass = 'bad_signature_accepted|missing_error_log'
    Command = 'npm --prefix functions test -- --test-name-pattern "stripeWebhookHandler returns 400 and logs when signature verification fails"'
    PassCriteria = 'Bad signature remains rejected and logged.'
    PositivePatterns = @('stripeWebhookHandler returns 400 and logs when signature verification fails')
    NegativePatterns = @('not ok ', 'ERR_TEST_FAILURE')
  }
)

if ($IncludeRulesValidation) {
  $baseCases += [ordered]@{
    Id = 'LH-RL-1'
    Name = 'Firestore Rules Validation'
    Category = 'Security Enforcement'
    FailureClass = 'rules_bypass|emulator_contract_gap'
    Command = 'pwsh -File tools/run_firestore_rules_tests.ps1'
    PassCriteria = 'Rules emulator must pass transaction and speaker lock checks.'
    PositivePatterns = @('Running Firestore rules tests', 'PASS')
    NegativePatterns = @('Write-Error', 'Error:')
  }
}

$pressureCases = @(
  [ordered]@{
    Id = 'LH-RM-1'
    Name = 'Room Session Churn'
    Category = 'Room Concurrency'
    FailureClass = 'duplicate_join|presence_drift|participant_desync'
    Command = 'flutter test --no-pub test/room_session_stress_test.dart'
    PassCriteria = 'Room churn remains deduped with no presence drift.'
    PositivePatterns = @('stress simulates room churn without duplicates or presence drift', 'All tests passed!')
    NegativePatterns = @('Some tests failed', 'Unhandled exception', 'Failed to load')
  },
  [ordered]@{
    Id = 'LH-PY-1'
    Name = 'Payment Replay Idempotency'
    Category = 'Payment Concurrency'
    FailureClass = 'double_debit|double_credit|idempotency_regression'
    Command = 'npm --prefix functions test -- --test-name-pattern "sendCoinTransferHandler deduplicates repeated idempotent calls|stripeWebhookHandler credits checkout.session.completed only once during replay"'
    PassCriteria = 'Replay and idempotent paths must remain one-write safe.'
    PositivePatterns = @('sendCoinTransferHandler deduplicates repeated idempotent calls', 'stripeWebhookHandler credits checkout.session.completed only once during replay')
    NegativePatterns = @('not ok ', 'ERR_TEST_FAILURE')
  }
)

function Invoke-HarnessCase {
  param(
    [int]$Cycle,
    [hashtable]$Case,
    [bool]$IsPressure
  )

  $startedAt = Get-Date
  $captured = @()

  Write-Host ''
  $prefix = if ($IsPressure) { '[PRESSURE]' } else { '[BASE]' }
  Write-Host "$prefix [Cycle $Cycle] $($Case.Id) $($Case.Name)" -ForegroundColor Yellow
  Write-Host "Category: $($Case.Category)"
  Write-Host "FailureClass: $($Case.FailureClass)"
  Write-Host "PassCriteria: $($Case.PassCriteria)"
  Write-Host "Command: $($Case.Command)" -ForegroundColor Cyan

  try {
    if ($IsWindows) {
      $captured = @(cmd.exe /d /s /c "$($Case.Command) 2>&1")
    } else {
      $captured = @(/bin/bash -lc "$($Case.Command) 2>&1")
    }
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
    cycle = $Cycle
    isPressure = $IsPressure
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

for ($cycle = 1; $cycle -le $Cycles; $cycle++) {
  Write-Host ''
  Write-Host "========== Launch Load Harness Cycle $cycle / $Cycles ==========" -ForegroundColor Green

  $ordered = @($baseCases)
  if ($Shuffle) {
    $ordered = $ordered | Sort-Object { Get-Random }
  }

  foreach ($case in $ordered) {
    $result = Invoke-HarnessCase -Cycle $cycle -Case $case -IsPressure $false
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

  if ($StopOnFailure -and @($results | Where-Object { -not $_.passed }).Count -gt 0) {
    break
  }

  if ($PressureRepeatsPerCycle -gt 0) {
    for ($repeat = 1; $repeat -le $PressureRepeatsPerCycle; $repeat++) {
      Write-Host "---- Pressure Repeat $repeat / $PressureRepeatsPerCycle (Cycle $cycle) ----" -ForegroundColor DarkYellow
      foreach ($pressure in $pressureCases) {
        $pressureResult = Invoke-HarnessCase -Cycle $cycle -Case $pressure -IsPressure $true
        [void]$results.Add($pressureResult)

        if (-not $pressureResult.passed) {
          [void]$failedCases.Add($pressureResult.caseId)
          Write-Host "FAIL (Pressure): $($pressureResult.caseId)" -ForegroundColor Red
          if ($StopOnFailure) {
            break
          }
        } else {
          Write-Host "PASS (Pressure): $($pressureResult.caseId)" -ForegroundColor Green
        }
      }

      if ($StopOnFailure -and @($results | Where-Object { -not $_.passed }).Count -gt 0) {
        break
      }
    }
  }

  if ($StopOnFailure -and @($results | Where-Object { -not $_.passed }).Count -gt 0) {
    break
  }
}

$resultList = @($results)
$totalRuns = $resultList.Count
$passedRuns = @($resultList | Where-Object { $_.passed }).Count
$failedRuns = @($resultList | Where-Object { -not $_.passed }).Count
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
    avgDurationMs = if ($runs.Count -eq 0) { 0 } else { [math]::Round((($runs | Measure-Object -Property durationMs -Average).Average), 2) }
    maxDurationMs = if ($runs.Count -eq 0) { 0 } else { ($runs | Measure-Object -Property durationMs -Maximum).Maximum }
  }
}

$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$jsonReportPath = Join-Path $ReportsDir "launch_load_harness_$timestamp.json"
$markdownPath = Join-Path $ReportsDir "launch_load_harness_$timestamp.md"

$report = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  harness = 'launch_load_harness_v1'
  validationMode = $ValidationMode
  cycles = $Cycles
  pressureRepeatsPerCycle = $PressureRepeatsPerCycle
  includeRulesValidation = [bool]$IncludeRulesValidation
  shuffle = [bool]$Shuffle
  verdict = $verdict
  totalRuns = $totalRuns
  passedRuns = $passedRuns
  failedRuns = $failedRuns
  failedCaseIds = @($failedCases | Select-Object -Unique)
  failureClassificationSummary = [ordered]@{
    primaryFailureBucket = $primaryFailureBucket
    counts = [PSCustomObject]$failureCounts
    failedClassifications = @($failedClassifications)
  }
  categorySummary = @($categorySummary)
  runs = @($resultList)
}

$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonReportPath -Encoding utf8

$lines = @(
  '# Launch Load Harness Report',
  '',
  "- GeneratedAtUtc: $($report.generatedAtUtc)",
  "- Harness: $($report.harness)",
  "- ValidationMode: $ValidationMode",
  "- Cycles: $Cycles",
  "- PressureRepeatsPerCycle: $PressureRepeatsPerCycle",
  "- IncludeRulesValidation: $([bool]$IncludeRulesValidation)",
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
  '| Case | Category | Pressure | Result | DurationMs | Failure Class |',
  '| --- | --- | --- | --- | ---: | --- |'
)

foreach ($item in $resultList) {
  $status = if ($item.passed) { 'PASS' } else { 'FAIL' }
  $pressure = if ($item.isPressure) { 'yes' } else { 'no' }
  $lines += "| $($item.caseId) | $($item.category) | $pressure | $status | $($item.durationMs) | $($item.failureClass) |"
}

$lines += ''
$lines += '## Gate Rule'
$lines += ''
$lines += '- PASS when every selected room and payment pressure case exits cleanly with expected positive signals.'
$lines += '- FAIL when any deterministic replay/authority/concurrency case fails.'

$lines | Out-File -FilePath $markdownPath -Encoding utf8

Write-Host ''
Write-Host '========== Launch Load Harness Summary ==========' -ForegroundColor Green
Write-Host "Verdict: $verdict"
Write-Host "Passed: $passedRuns / $totalRuns"
Write-Host "JSON report: $jsonReportPath"
Write-Host "Markdown report: $markdownPath"

if ($failedRuns -gt 0 -and $ValidationMode -eq 'enforce') {
  exit 1
}

exit 0
