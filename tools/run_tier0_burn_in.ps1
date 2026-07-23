param(
  [int]$Cycles = 5,
  [int]$PressureRepeatsPerCycle = 2,
  [switch]$Shuffle,
  [switch]$StopOnFailure
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

$tier0Cases = @(
  @{ Id = 'MC-1'; Name = 'Ordering Determinism'; Command = 'flutter test --no-pub test/home_controller_test.dart' },
  @{ Id = 'MC-2'; Name = 'Duplicate Suppression'; Command = 'flutter test --no-pub test/chat_pane_view_test.dart' },
  @{ Id = 'MC-3'; Name = 'Offline Queue Integrity'; Command = 'flutter test --no-pub test/messaging_retention_test.dart' },
  @{ Id = 'MC-4'; Name = 'Crash Recovery Consistency'; Command = 'flutter test --no-pub test/app_integration_test.dart' },
  @{ Id = 'PS-1'; Name = 'Lifecycle Correctness'; Command = 'flutter test --no-pub test/presence_service_test.dart' },
  @{ Id = 'PS-2'; Name = 'Multi-Device Truth Convergence'; Command = 'flutter test --no-pub test/presence_guardrail_test.dart' },
  @{ Id = 'PS-3'; Name = 'Partition Recovery'; Command = 'flutter test --no-pub test/room_session_stress_test.dart' },
  @{ Id = 'PS-4'; Name = 'Room Dominance Rule'; Command = 'flutter test --no-pub test/live_room_screen_test.dart' },
  @{ Id = 'RD-1'; Name = 'Readiness Checklist'; Command = 'flutter test --no-pub test/room_launch_checklist_test.dart' }
)

$pressureCases = @(
  @{ Id = 'MC-2'; Name = 'Duplicate Suppression'; Command = 'flutter test --no-pub test/chat_pane_view_test.dart' },
  @{ Id = 'PS-3'; Name = 'Partition Recovery'; Command = 'flutter test --no-pub test/room_session_stress_test.dart' }
)

function Invoke-Case {
  param(
    [int]$Cycle,
    [string]$CaseId,
    [string]$CaseName,
    [string]$Command,
    [bool]$IsPressure
  )

  $start = Get-Date
  Write-Host "[Cycle $Cycle] Running $CaseId $CaseName" -ForegroundColor Cyan
  Write-Host "[Cycle $Cycle] Command: $Command"

  Invoke-Expression $Command | Out-Host
  $exitCode = $LASTEXITCODE
  $end = Get-Date
  $durationMs = [int][Math]::Round(($end - $start).TotalMilliseconds)

  return [PSCustomObject]@{
    cycle = $Cycle
    caseId = $CaseId
    caseName = $CaseName
    isPressure = $IsPressure
    command = $Command
    exitCode = $exitCode
    startedAtUtc = $start.ToUniversalTime().ToString('o')
    endedAtUtc = $end.ToUniversalTime().ToString('o')
    durationMs = $durationMs
    passed = ($exitCode -eq 0)
  }
}

$allResults = New-Object System.Collections.ArrayList
$failed = $false

for ($cycle = 1; $cycle -le $Cycles; $cycle++) {
  Write-Host ""
  Write-Host "========== Tier 0 Burn-In Cycle $cycle / $Cycles ==========" -ForegroundColor Yellow

  $orderedCases = $tier0Cases
  if ($Shuffle) {
    $orderedCases = $tier0Cases | Sort-Object { Get-Random }
  }

  foreach ($case in $orderedCases) {
    $result = Invoke-Case -Cycle $cycle -CaseId $case.Id -CaseName $case.Name -Command $case.Command -IsPressure $false
    [void]$allResults.Add($result)

    if (-not $result.passed) {
      Write-Host "[Cycle $cycle] FAIL: $($case.Id)" -ForegroundColor Red
      $failed = $true
      if ($StopOnFailure) {
        break
      }
    }
  }

  if ($failed -and $StopOnFailure) {
    break
  }

  if ($PressureRepeatsPerCycle -gt 0) {
    for ($i = 1; $i -le $PressureRepeatsPerCycle; $i++) {
      foreach ($pressure in $pressureCases) {
        $pressureResult = Invoke-Case -Cycle $cycle -CaseId $pressure.Id -CaseName $pressure.Name -Command $pressure.Command -IsPressure $true
        [void]$allResults.Add($pressureResult)

        if (-not $pressureResult.passed) {
          Write-Host "[Cycle $cycle] FAIL (Pressure): $($pressure.Id)" -ForegroundColor Red
          $failed = $true
          if ($StopOnFailure) {
            break
          }
        }
      }

      if ($failed -and $StopOnFailure) {
        break
      }
    }
  }

  if ($failed -and $StopOnFailure) {
    break
  }
}

$resultList = @($allResults)
$totalRuns = $resultList.Count
$failedRuns = @($resultList | Where-Object { -not $_.passed }).Count
$passedRuns = $totalRuns - $failedRuns

$byCase = $resultList | Group-Object caseId | ForEach-Object {
  $caseId = $_.Name
  $runs = @($_.Group)
  $fails = @($runs | Where-Object { -not $_.passed }).Count
  $durations = @($runs | ForEach-Object { $_.durationMs } | Where-Object { $_ -ne $null })
  $maxDurationMs = if ($durations.Count -eq 0) { 0 } else { ($durations | Measure-Object -Maximum).Maximum }
  $minDurationMs = if ($durations.Count -eq 0) { 0 } else { ($durations | Measure-Object -Minimum).Minimum }
  $avgDurationMs = if ($durations.Count -eq 0) { 0 } else { [math]::Round((($durations | Measure-Object -Average).Average), 2) }
  [PSCustomObject]@{
    CaseId = $caseId
    Runs = $runs.Count
    Fails = $fails
    PassRate = if ($runs.Count -eq 0) { 0 } else { [math]::Round((($runs.Count - $fails) / $runs.Count) * 100, 2) }
    MinDurationMs = $minDurationMs
    AvgDurationMs = $avgDurationMs
    MaxDurationMs = $maxDurationMs
  }
}

Write-Host ""
Write-Host "========== Burn-In Summary ==========" -ForegroundColor Yellow
Write-Host "Total runs: $totalRuns"
Write-Host "Passed runs: $passedRuns"
Write-Host "Failed runs: $failedRuns"

$byCase | Sort-Object CaseId | Format-Table -AutoSize | Out-String | Write-Host

$reportDir = Join-Path (Join-Path $PSScriptRoot '..') 'tools\reports'
if (-not (Test-Path $reportDir)) {
  New-Item -Path $reportDir -ItemType Directory | Out-Null
}

$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$reportPath = Join-Path $reportDir "tier0_burn_in_$timestamp.json"

$report = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  cycles = $Cycles
  shuffle = [bool]$Shuffle
  pressureRepeatsPerCycle = $PressureRepeatsPerCycle
  totalRuns = $totalRuns
  passedRuns = $passedRuns
  failedRuns = $failedRuns
  caseSummary = $byCase
  runs = $resultList
}

$report | ConvertTo-Json -Depth 8 | Out-File -FilePath $reportPath -Encoding utf8
Write-Host "Report written: $reportPath"

if ($failedRuns -gt 0) {
  exit 1
}

exit 0