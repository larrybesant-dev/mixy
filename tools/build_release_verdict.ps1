param(
  [string]$ReportsDir = 'tools/reports',
  [string]$OutputPath = 'tools/reports/release_candidate_verdict.json',
  [string]$MarkdownOutputPath = 'tools/reports/release_candidate_verdict.md',
  [string]$HistoryDir = 'tools/reports/history',
  [string]$HistoryIndexPath = 'tools/reports/history/verdict_index.json',
  [int]$HistoryWindow = 10
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ReportsDir)) {
  Write-Error "Reports directory not found: $ReportsDir"
  exit 1
}

function Get-LatestReport {
  param(
    [string]$Pattern
  )

  $file = Get-ChildItem -Path $ReportsDir -Filter $Pattern -File |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

  if ($null -eq $file) {
    return $null
  }

  $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
  return [PSCustomObject]@{
    Path = $file.FullName
    Name = $file.Name
    Data = $json
  }
}

$tier0 = Get-LatestReport -Pattern 'tier0_burn_in_*.json'
$tier1 = Get-LatestReport -Pattern 'tier1_burn_in_*.json'
$roomGate = Get-LatestReport -Pattern 'room_release_stress_gate_*.json'

if ($null -eq $tier0 -or $null -eq $tier1 -or $null -eq $roomGate) {
  Write-Error 'Missing tier0, tier1, or room release gate report. Cannot build release verdict.'
  exit 1
}

function Build-GateSummary {
  param(
    [string]$Gate,
    [object]$Report
  )

  $reportData = $Report.Data
  $pass = if ($null -ne $reportData.failedRuns) {
    ($reportData.failedRuns -eq 0)
  } elseif ($null -ne $reportData.verdict) {
    ($reportData.verdict -eq 'PASS')
  } else {
    $false
  }

  $cycles = if ($null -ne $reportData.cycles) {
    [int]$reportData.cycles
  } else {
    1
  }

  $caseSummary = if ($null -ne $reportData.caseSummary) {
    $reportData.caseSummary
  } elseif ($null -ne $reportData.cases) {
    $reportData.cases
  } else {
    @()
  }

  return [PSCustomObject]@{
    gate = $Gate
    pass = $pass
    totalRuns = [int]$reportData.totalRuns
    passedRuns = [int]$reportData.passedRuns
    failedRuns = [int]$reportData.failedRuns
    cycles = $cycles
    sourceReport = $Report.Name
    caseSummary = $caseSummary
    rawReport = $reportData
  }
}

function Get-RunRows {
  param(
    [object]$GateSummary
  )

  if ($null -eq $GateSummary -or $null -eq $GateSummary.rawReport) {
    return @()
  }

  if ($null -ne $GateSummary.rawReport.runs) {
    return @($GateSummary.rawReport.runs)
  }

  if ($null -ne $GateSummary.caseSummary) {
    return @($GateSummary.caseSummary)
  }

  return @()
}

function Get-Text {
  param(
    [object]$Value
  )

  if ($null -eq $Value) {
    return ''
  }

  return [string]$Value
}

function Get-FailureBucket {
  param(
    [string]$Gate,
    [object]$Run
  )

  $gateValue = Get-Text -Value $Gate
  $caseId = Get-Text -Value (Get-FirstPropertyValue -Object $Run -Names @('caseId', 'CaseId') -Default '')
  $caseName = Get-Text -Value (Get-FirstPropertyValue -Object $Run -Names @('caseName', 'CaseName') -Default '')
  $category = Get-Text -Value (Get-FirstPropertyValue -Object $Run -Names @('category', 'Category') -Default '')
  $failureClass = Get-Text -Value (Get-FirstPropertyValue -Object $Run -Names @('failureClass', 'FailureClass') -Default '')
  $command = Get-Text -Value (Get-FirstPropertyValue -Object $Run -Names @('command', 'Command') -Default '')
  $negativeMatches = Get-Text -Value ((Get-FirstPropertyValue -Object $Run -Names @('negativeMatches') -Default @()) -join ' ')
  $signal = "$gateValue $caseId $caseName $category $failureClass $command $negativeMatches".ToLowerInvariant()
  $exitCode = [int](Get-Numeric -Value (Get-FirstPropertyValue -Object $Run -Names @('exitCode', 'ExitCode') -Default 0))

  $isInfra = (
    $exitCode -in @(124, 130, 137, 143) -or
    $signal -match 'timeout|timed out|cancelled|killed|infra|network|econn|socket|dns|service unavailable|resource exhausted'
  )
  if ($isInfra) {
    return 'TIMEOUT / INFRA FAILURE'
  }

  if ($signal -match 'payment|stripe|checkout|coin|webhook|idempotency|double_debit|double_credit|lh-py-|py-') {
    return 'PAYMENT FAILURE'
  }

  if ($signal -match 'rules|firestore|security enforcement|emulator|rule' -or $caseId -match '^(LH-RL-|RL-)') {
    return 'RULES FAILURE'
  }

  if ($signal -match 'room|presence|host|mic|speaker|live|reconnect|participant|slot|rs-|ps-|lh-rm-' -or $gateValue -eq 'room') {
    return 'ROOM FAILURE'
  }

  return 'TIMEOUT / INFRA FAILURE'
}

function Build-FailureClassification {
  param(
    [object[]]$GateSummaries
  )

  $counts = [ordered]@{
    'ROOM FAILURE' = 0
    'PAYMENT FAILURE' = 0
    'RULES FAILURE' = 0
    'TIMEOUT / INFRA FAILURE' = 0
  }

  $classifiedFailures = @()

  foreach ($gate in @($GateSummaries)) {
    $runs = Get-RunRows -GateSummary $gate
    foreach ($run in $runs) {
      $passedValue = Get-FirstPropertyValue -Object $run -Names @('passed', 'Passed') -Default $null
      $failedCount = Get-Numeric -Value (Get-FirstPropertyValue -Object $run -Names @('Fails') -Default 0)

      $isFailedRun = $false
      if ($null -ne $passedValue) {
        $isFailedRun = -not [bool]$passedValue
      } elseif ($failedCount -gt 0) {
        $isFailedRun = $true
      }

      if (-not $isFailedRun) {
        continue
      }

      $bucket = Get-FailureBucket -Gate $gate.gate -Run $run
      $counts[$bucket] = [int]$counts[$bucket] + 1

      $classifiedFailures += [PSCustomObject]@{
        gate = $gate.gate
        caseId = Get-FirstPropertyValue -Object $run -Names @('caseId', 'CaseId') -Default 'unknown'
        caseName = Get-FirstPropertyValue -Object $run -Names @('caseName', 'CaseName') -Default 'unknown'
        failureBucket = $bucket
      }
    }
  }

  $primaryBucket = ($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
  if (($counts.Values | Measure-Object -Sum).Sum -eq 0) {
    $primaryBucket = 'NONE'
  }

  return [PSCustomObject]@{
    modelVersion = 'failure_classification_v1'
    primaryFailureBucket = $primaryBucket
    counts = [PSCustomObject]$counts
    classifiedFailures = @($classifiedFailures)
  }
}

function Build-ExecutionSummary {
  param(
    [object[]]$GateSummaries
  )

  $gateExecution = @()
  $totalDurationMs = 0.0
  $totalRetries = 0
  $totalRetryableRuns = 0

  foreach ($gate in @($GateSummaries)) {
    $runs = Get-RunRows -GateSummary $gate
    $durations = @()
    $gateRetries = 0
    $gateRetryableRuns = 0

    foreach ($run in $runs) {
      $duration = Get-Numeric -Value (Get-FirstPropertyValue -Object $run -Names @('durationMs', 'DurationMs') -Default 0)
      if ($duration -gt 0) {
        $durations += $duration
      }

      $retryCount = [int](Get-Numeric -Value (Get-FirstPropertyValue -Object $run -Names @('retryCount', 'RetryCount') -Default 0))
      $isPressure = [bool](Get-FirstPropertyValue -Object $run -Names @('isPressure', 'IsPressure') -Default $false)

      if ($isPressure -or $retryCount -gt 0) {
        $gateRetryableRuns += 1
      }
      $gateRetries += [Math]::Max(0, $retryCount)
    }

    $gateTotalDurationMs = if ($durations.Count -eq 0) { 0 } else { [math]::Round((($durations | Measure-Object -Sum).Sum), 2) }
    $gateTotalRuns = [int](Get-Numeric -Value $gate.totalRuns)
    $gateRetryRate = if ($gateTotalRuns -eq 0) { 0 } else { [math]::Round(($gateRetries / $gateTotalRuns) * 100, 2) }

    $gateExecution += [PSCustomObject]@{
      gate = $gate.gate
      totalDurationMs = $gateTotalDurationMs
      retryCount = $gateRetries
      retryRate = $gateRetryRate
    }

    $totalDurationMs += $gateTotalDurationMs
    $totalRetries += $gateRetries
    $totalRetryableRuns += $gateRetryableRuns
  }

  $overallRuns = [int](Get-Numeric -Value (@($GateSummaries | Measure-Object -Property totalRuns -Sum).Sum))
  $overallRetryRate = if ($overallRuns -eq 0) { 0 } else { [math]::Round(($totalRetries / $overallRuns) * 100, 2) }

  return [PSCustomObject]@{
    modelVersion = 'execution_summary_v1'
    totalDurationMs = [math]::Round($totalDurationMs, 2)
    retryCount = $totalRetries
    retryRate = $overallRetryRate
    gateExecution = @($gateExecution)
  }
}

function Build-RegressionComparison {
  param(
    [string]$HistoryDir,
    [int]$WindowSize,
    [object]$CurrentPoint
  )

  $points = @()

  if (Test-Path $HistoryDir) {
    $historyFiles = @(Get-ChildItem -Path $HistoryDir -Filter 'release_candidate_verdict_*.json' -File | Sort-Object LastWriteTimeUtc)
    foreach ($historyFile in $historyFiles) {
      try {
        $raw = Get-Content -Path $historyFile.FullName -Raw | ConvertFrom-Json
      } catch {
        continue
      }

      $totalRuns = 0.0
      $failedRuns = 0.0
      if ($null -ne $raw.gates) {
        $totalRuns = Get-Numeric -Value (@($raw.gates | Measure-Object -Property totalRuns -Sum).Sum)
        $failedRuns = Get-Numeric -Value (@($raw.gates | Measure-Object -Property failedRuns -Sum).Sum)
      }

      $failureRate = if ($totalRuns -eq 0) { 0 } else { [math]::Round(($failedRuns / $totalRuns) * 100, 2) }

      $qualitySignals = Get-FirstPropertyValue -Object $raw -Names @('qualitySignals') -Default $null
      $executionTotalMs = 0
      $retryRate = 0
      if ($null -ne $qualitySignals) {
        $executionTotalMs = Get-Numeric -Value (Get-FirstPropertyValue -Object $qualitySignals.execution -Names @('totalDurationMs') -Default 0)
        $retryRate = Get-Numeric -Value (Get-FirstPropertyValue -Object $qualitySignals.reliability -Names @('overallRetryRate') -Default 0)
      }

      $points += [PSCustomObject]@{
        generatedAtUtc = Get-IsoTimeOrNow -Value $raw.generatedAtUtc
        executionTotalMs = $executionTotalMs
        failureRate = $failureRate
        retryRate = $retryRate
      }
    }
  }

  $points += [PSCustomObject]@{
    generatedAtUtc = Get-IsoTimeOrNow -Value $CurrentPoint.generatedAtUtc
    executionTotalMs = Get-Numeric -Value $CurrentPoint.executionTotalMs
    failureRate = Get-Numeric -Value $CurrentPoint.failureRate
    retryRate = Get-Numeric -Value $CurrentPoint.retryRate
  }

  $ordered = @($points | Sort-Object generatedAtUtc)
  if ($ordered.Count -gt $WindowSize) {
    $ordered = @($ordered | Select-Object -Last $WindowSize)
  }

  $latest = $ordered[-1]
  $baselinePoints = if ($ordered.Count -gt 1) { @($ordered | Select-Object -SkipLast 1) } else { @() }

  $baselineExecution = if ($baselinePoints.Count -eq 0) { 0 } else { [math]::Round((($baselinePoints | Measure-Object -Property executionTotalMs -Average).Average), 2) }
  $baselineFailureRate = if ($baselinePoints.Count -eq 0) { 0 } else { [math]::Round((($baselinePoints | Measure-Object -Property failureRate -Average).Average), 2) }
  $baselineRetryRate = if ($baselinePoints.Count -eq 0) { 0 } else { [math]::Round((($baselinePoints | Measure-Object -Property retryRate -Average).Average), 2) }

  $executionTimeDriftPercent = if ($baselineExecution -eq 0) { 0 } else { [math]::Round((($latest.executionTotalMs - $baselineExecution) / $baselineExecution) * 100, 2) }
  $failureFrequencyDrift = [math]::Round(($latest.failureRate - $baselineFailureRate), 2)
  $retryRateDrift = [math]::Round(($latest.retryRate - $baselineRetryRate), 2)

  return [PSCustomObject]@{
    modelVersion = 'run_regression_v1'
    windowSize = $WindowSize
    comparedRunCount = $ordered.Count
    latest = [PSCustomObject]@{
      executionTotalMs = [math]::Round($latest.executionTotalMs, 2)
      failureRate = [math]::Round($latest.failureRate, 2)
      retryRate = [math]::Round($latest.retryRate, 2)
    }
    baseline = [PSCustomObject]@{
      executionTotalMs = $baselineExecution
      failureRate = $baselineFailureRate
      retryRate = $baselineRetryRate
    }
    drift = [PSCustomObject]@{
      executionTimeDriftPercent = $executionTimeDriftPercent
      failureFrequencyDrift = $failureFrequencyDrift
      retryRateDrift = $retryRateDrift
    }
  }
}

function Build-PreLaunchScore {
  param(
    [bool]$ReleasePass,
    [double]$CyclePassRate,
    [double]$AverageDriftScore,
    [double]$FailureRate,
    [double]$RetryRate,
    [double]$ExecutionTimeDriftPercent
  )

  $stressPenalty = ($FailureRate * 1.0) + ($RetryRate * 2.0) + ([math]::Max(0, $ExecutionTimeDriftPercent) * 0.2) + ((100 - $AverageDriftScore) * 0.6)
  $stressResilience = [math]::Max(0, [math]::Round((100 - [math]::Min(100, $stressPenalty)), 2))

  $stabilityScore = [math]::Round((0.65 * $CyclePassRate) + (0.35 * $stressResilience), 2)
  $stabilityScore = [math]::Max(0, [math]::Min(100, $stabilityScore))

  if (-not $ReleasePass) {
    $stabilityScore = [math]::Min($stabilityScore, 49)
  }

  $band = if ($stabilityScore -ge 90) {
    'launch_ready'
  } elseif ($stabilityScore -ge 75) {
    'candidate'
  } elseif ($stabilityScore -ge 60) {
    'watch'
  } else {
    'hold'
  }

  return [PSCustomObject]@{
    modelVersion = 'pre_launch_score_v1'
    stabilityScore = $stabilityScore
    scoreBand = $band
    components = [PSCustomObject]@{
      cyclePassRate = [math]::Round($CyclePassRate, 2)
      stressResilience = $stressResilience
      averageDriftScore = [math]::Round($AverageDriftScore, 2)
      failureRate = [math]::Round($FailureRate, 2)
      retryRate = [math]::Round($RetryRate, 2)
      executionTimeDriftPercent = [math]::Round($ExecutionTimeDriftPercent, 2)
    }
  }
}

function Get-FirstPropertyValue {
  param(
    [object]$Object,
    [string[]]$Names,
    [object]$Default = $null
  )

  if ($null -eq $Object) {
    return $Default
  }

  foreach ($name in $Names) {
    $property = $Object.PSObject.Properties[$name]
    if ($null -ne $property) {
      return $property.Value
    }
  }

  return $Default
}

function Get-Numeric {
  param(
    [object]$Value,
    [double]$Default = 0
  )

  if ($null -eq $Value) {
    return $Default
  }

  $parsed = 0.0
  if ([double]::TryParse($Value.ToString(), [ref]$parsed)) {
    return $parsed
  }

  return $Default
}

function Get-IsoTimeOrNow {
  param(
    [object]$Value
  )

  if ($null -eq $Value) {
    return (Get-Date).ToUniversalTime()
  }

  try {
    return ([datetime]$Value).ToUniversalTime()
  } catch {
    return (Get-Date).ToUniversalTime()
  }
}

function Build-DriftSummary {
  param(
    [object]$GateSummary
  )

  $cases = @($GateSummary.caseSummary)
  if ($cases.Count -eq 0) {
    return [PSCustomObject]@{
      averageVariabilityRatio = 1.0
      maxVariabilityRatio = 1.0
      driftScore = 0
      topCases = @()
    }
  }

  $ratios = @()
  $topCases = @()

  foreach ($case in $cases) {
    $caseId = Get-FirstPropertyValue -Object $case -Names @('CaseId', 'caseId') -Default 'unknown'
    $avg = Get-Numeric -Value (Get-FirstPropertyValue -Object $case -Names @('AvgDurationMs', 'avgDurationMs', 'durationMs') -Default 0)
    $min = Get-Numeric -Value (Get-FirstPropertyValue -Object $case -Names @('MinDurationMs', 'minDurationMs', 'durationMs') -Default 0)
    $max = Get-Numeric -Value (Get-FirstPropertyValue -Object $case -Names @('MaxDurationMs', 'maxDurationMs', 'durationMs') -Default 0)

    # Backward compatibility for older burn-in reports that only recorded max duration.
    if ($avg -le 0 -and $max -gt 0) {
      $avg = $max
    }
    if ($min -le 0 -and $max -gt 0) {
      $min = $max
    }

    if ($avg -le 0) {
      $ratio = 1.0
    } else {
      $ratio = [math]::Max(0, ($max - $min) / $avg)
    }

    $ratios += $ratio
    $topCases += [PSCustomObject]@{
      caseId = $caseId
      minDurationMs = $min
      avgDurationMs = $avg
      maxDurationMs = $max
      variabilityRatio = [math]::Round($ratio, 4)
    }
  }

  $avgRatio = ($ratios | Measure-Object -Average).Average
  $maxRatio = ($ratios | Measure-Object -Maximum).Maximum
  $driftScore = [math]::Max(0, 100 - [math]::Min(100, [math]::Round($avgRatio * 100, 2)))

  return [PSCustomObject]@{
    averageVariabilityRatio = [math]::Round($avgRatio, 4)
    maxVariabilityRatio = [math]::Round($maxRatio, 4)
    driftScore = [math]::Round($driftScore, 2)
    topCases = @($topCases | Sort-Object variabilityRatio -Descending | Select-Object -First 3)
  }
}

function Build-GateScore {
  param(
    [object]$GateSummary,
    [object]$Drift
  )

  $passRate = if ($GateSummary.totalRuns -eq 0) { 0 } else { [math]::Round(($GateSummary.passedRuns / $GateSummary.totalRuns) * 100, 2) }
  $failurePenalty = if ($GateSummary.failedRuns -gt 0) { 40 } else { 0 }

  $score = (0.75 * $passRate) + (0.25 * $Drift.driftScore) - $failurePenalty
  return [math]::Max(0, [math]::Min(100, [math]::Round($score, 2)))
}

$tier0Summary = Build-GateSummary -Gate 'tier0' -Report $tier0
$tier1Summary = Build-GateSummary -Gate 'tier1' -Report $tier1
$roomSummary = Build-GateSummary -Gate 'room' -Report $roomGate

$tier0Drift = Build-DriftSummary -GateSummary $tier0Summary
$tier1Drift = Build-DriftSummary -GateSummary $tier1Summary
$roomDrift = Build-DriftSummary -GateSummary $roomSummary

$tier0Score = Build-GateScore -GateSummary $tier0Summary -Drift $tier0Drift
$tier1Score = Build-GateScore -GateSummary $tier1Summary -Drift $tier1Drift
$roomScore = Build-GateScore -GateSummary $roomSummary -Drift $roomDrift

$releasePass = $tier0Summary.pass -and $tier1Summary.pass -and $roomSummary.pass

$confidenceScore = [math]::Round((0.4 * $tier0Score) + (0.4 * $tier1Score) + (0.2 * $roomScore), 2)

if (-not $releasePass) {
  $confidenceScore = [math]::Min($confidenceScore, 49)
}

$gateSummaries = @($tier0Summary, $tier1Summary, $roomSummary)
$executionSummary = Build-ExecutionSummary -GateSummaries $gateSummaries
$failureClassification = Build-FailureClassification -GateSummaries $gateSummaries

$overallTotalRuns = Get-Numeric -Value (@($gateSummaries | Measure-Object -Property totalRuns -Sum).Sum)
$overallFailedRuns = Get-Numeric -Value (@($gateSummaries | Measure-Object -Property failedRuns -Sum).Sum)
$overallPassedRuns = [math]::Max(0, ($overallTotalRuns - $overallFailedRuns))
$overallFailureRate = if ($overallTotalRuns -eq 0) { 0 } else { [math]::Round(($overallFailedRuns / $overallTotalRuns) * 100, 2) }
$overallRetryRate = [double]$executionSummary.retryRate
$averageDriftScore = [math]::Round((($tier0Drift.driftScore + $tier1Drift.driftScore + $roomDrift.driftScore) / 3), 2)

$regressionComparison = Build-RegressionComparison -HistoryDir $HistoryDir -WindowSize $HistoryWindow -CurrentPoint ([PSCustomObject]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  executionTotalMs = $executionSummary.totalDurationMs
  failureRate = $overallFailureRate
  retryRate = $overallRetryRate
})

$cyclePassRate = if ($overallTotalRuns -eq 0) { 0 } else { [math]::Round(($overallPassedRuns / $overallTotalRuns) * 100, 2) }
$preLaunchScore = Build-PreLaunchScore -ReleasePass $releasePass -CyclePassRate $cyclePassRate -AverageDriftScore $averageDriftScore -FailureRate $overallFailureRate -RetryRate $overallRetryRate -ExecutionTimeDriftPercent $regressionComparison.drift.executionTimeDriftPercent

$confidenceBand = if ($confidenceScore -ge 90) {
  'very_high'
} elseif ($confidenceScore -ge 75) {
  'high'
} elseif ($confidenceScore -ge 60) {
  'moderate'
} else {
  'low'
}

$verdict = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  gitRef = $env:GITHUB_REF
  gitSha = $env:GITHUB_SHA
  runId = $env:GITHUB_RUN_ID
  runNumber = $env:GITHUB_RUN_NUMBER
  releaseCandidateVerdict = if ($releasePass) { 'PASS' } else { 'FAIL' }
  releaseConfidenceScore = $confidenceScore
  releaseConfidenceBand = $confidenceBand
  scoringModel = [ordered]@{
    modelVersion = 'rc_confidence_v3'
    tierWeight = [ordered]@{
      tier0 = 0.4
      tier1 = 0.4
      room = 0.2
    }
    gateScoreFormula = 'gateScore = 0.75*passRate + 0.25*driftScore - failurePenalty(40 when failedRuns>0)'
    driftFormula = 'driftScore = 100 - min(100, avg((max-min)/avg)*100)'
  }
  qualitySignals = [ordered]@{
    failureClassification = $failureClassification
    execution = $executionSummary
    reliability = [ordered]@{
      totalRuns = [int]$overallTotalRuns
      passedRuns = [int]$overallPassedRuns
      failedRuns = [int]$overallFailedRuns
      overallFailureRate = $overallFailureRate
      overallRetryRate = $overallRetryRate
    }
    regressionComparison = $regressionComparison
    preLaunchScore = $preLaunchScore
  }
  gateScores = @(
    [ordered]@{
      gate = 'tier0'
      score = $tier0Score
      passRate = if ($tier0Summary.totalRuns -eq 0) { 0 } else { [math]::Round(($tier0Summary.passedRuns / $tier0Summary.totalRuns) * 100, 2) }
      drift = $tier0Drift
    },
    [ordered]@{
      gate = 'tier1'
      score = $tier1Score
      passRate = if ($tier1Summary.totalRuns -eq 0) { 0 } else { [math]::Round(($tier1Summary.passedRuns / $tier1Summary.totalRuns) * 100, 2) }
      drift = $tier1Drift
    },
    [ordered]@{
      gate = 'room'
      score = $roomScore
      passRate = if ($roomSummary.totalRuns -eq 0) { 0 } else { [math]::Round(($roomSummary.passedRuns / $roomSummary.totalRuns) * 100, 2) }
      drift = $roomDrift
    }
  )
  gates = @(
    $tier0Summary,
    $tier1Summary,
    $roomSummary
  )
}

$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
  New-Item -Path $outputDir -ItemType Directory | Out-Null
}

$verdict | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding utf8

if (-not (Test-Path $HistoryDir)) {
  New-Item -Path $HistoryDir -ItemType Directory | Out-Null
}

$refName = if ([string]::IsNullOrWhiteSpace($env:GITHUB_REF_NAME)) { 'local' } else { $env:GITHUB_REF_NAME }
$safeRefName = ($refName -replace '[^A-Za-z0-9._-]', '_')
$runIdentity = if ([string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) {
  (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
} else {
  $env:GITHUB_RUN_ID
}

$historyFileName = "release_candidate_verdict_${safeRefName}_${runIdentity}.json"
$historyFilePath = Join-Path $HistoryDir $historyFileName
$duplicateCounter = 1
while (Test-Path $historyFilePath) {
  $historyFileName = "release_candidate_verdict_${safeRefName}_${runIdentity}_$duplicateCounter.json"
  $historyFilePath = Join-Path $HistoryDir $historyFileName
  $duplicateCounter += 1
}

$verdict | ConvertTo-Json -Depth 10 | Out-File -FilePath $historyFilePath -Encoding utf8

$indexDir = Split-Path -Path $HistoryIndexPath -Parent
if (-not (Test-Path $indexDir)) {
  New-Item -Path $indexDir -ItemType Directory | Out-Null
}

$index = @()
if (Test-Path $HistoryIndexPath) {
  $rawIndex = Get-Content -Path $HistoryIndexPath -Raw
  if (-not [string]::IsNullOrWhiteSpace($rawIndex)) {
    $parsedIndex = $rawIndex | ConvertFrom-Json
    $index = @($parsedIndex)
  }
}

$index += [PSCustomObject]@{
  generatedAtUtc = $verdict.generatedAtUtc
  file = $historyFileName
  gitRef = $verdict.gitRef
  gitSha = $verdict.gitSha
  runId = $verdict.runId
  runNumber = $verdict.runNumber
  releaseCandidateVerdict = $verdict.releaseCandidateVerdict
  releaseConfidenceScore = $verdict.releaseConfidenceScore
}

$index | ConvertTo-Json -Depth 10 | Out-File -FilePath $HistoryIndexPath -Encoding utf8

$mdLines = @(
  '# Release Candidate Verdict',
  '',
  "- GeneratedAtUtc: $($verdict.generatedAtUtc)",
  "- GitRef: $($verdict.gitRef)",
  "- GitSha: $($verdict.gitSha)",
  "- Verdict: $($verdict.releaseCandidateVerdict)",
  "- ConfidenceScore: $($verdict.releaseConfidenceScore)",
  "- ConfidenceBand: $($verdict.releaseConfidenceBand)",
  '',
  '## Gate Summary',
  '',
  '| Gate | Pass | TotalRuns | PassedRuns | FailedRuns | Score | DriftScore | AvgVariability | MaxVariability | SourceReport |',
  '|---|---:|---:|---:|---:|---:|---:|---:|---:|---|',
  "| tier0 | $($tier0Summary.pass) | $($tier0Summary.totalRuns) | $($tier0Summary.passedRuns) | $($tier0Summary.failedRuns) | $tier0Score | $($tier0Drift.driftScore) | $($tier0Drift.averageVariabilityRatio) | $($tier0Drift.maxVariabilityRatio) | $($tier0Summary.sourceReport) |",
  "| tier1 | $($tier1Summary.pass) | $($tier1Summary.totalRuns) | $($tier1Summary.passedRuns) | $($tier1Summary.failedRuns) | $tier1Score | $($tier1Drift.driftScore) | $($tier1Drift.averageVariabilityRatio) | $($tier1Drift.maxVariabilityRatio) | $($tier1Summary.sourceReport) |",
  "| room | $($roomSummary.pass) | $($roomSummary.totalRuns) | $($roomSummary.passedRuns) | $($roomSummary.failedRuns) | $roomScore | $($roomDrift.driftScore) | $($roomDrift.averageVariabilityRatio) | $($roomDrift.maxVariabilityRatio) | $($roomSummary.sourceReport) |",
  '',
  '## Failure Classification',
  '',
  "- PrimaryFailureBucket: $($failureClassification.primaryFailureBucket)",
  "- ROOM FAILURE: $($failureClassification.counts.'ROOM FAILURE')",
  "- PAYMENT FAILURE: $($failureClassification.counts.'PAYMENT FAILURE')",
  "- RULES FAILURE: $($failureClassification.counts.'RULES FAILURE')",
  "- TIMEOUT / INFRA FAILURE: $($failureClassification.counts.'TIMEOUT / INFRA FAILURE')",
  '',
  '## Regression Comparison',
  '',
  "- ComparedRunCount: $($regressionComparison.comparedRunCount)",
  "- ExecutionTimeDriftPercent: $($regressionComparison.drift.executionTimeDriftPercent)",
  "- FailureFrequencyDrift: $($regressionComparison.drift.failureFrequencyDrift)",
  "- RetryRateDrift: $($regressionComparison.drift.retryRateDrift)",
  '',
  '## Pre-Launch Score',
  '',
  "- StabilityScore: $($preLaunchScore.stabilityScore)",
  "- ScoreBand: $($preLaunchScore.scoreBand)",
  "- CyclePassRate: $($preLaunchScore.components.cyclePassRate)",
  "- StressResilience: $($preLaunchScore.components.stressResilience)",
  '',
  '## Top Drift Cases',
  '',
  '### Tier 0',
  '| Case | MinMs | AvgMs | MaxMs | Variability |',
  '|---|---:|---:|---:|---:|'
)

foreach ($case in $tier0Drift.topCases) {
  $mdLines += "| $($case.caseId) | $($case.minDurationMs) | $($case.avgDurationMs) | $($case.maxDurationMs) | $($case.variabilityRatio) |"
}

$mdLines += @(
  '',
  '### Tier 1',
  '| Case | MinMs | AvgMs | MaxMs | Variability |',
  '|---|---:|---:|---:|---:|'
)

foreach ($case in $tier1Drift.topCases) {
  $mdLines += "| $($case.caseId) | $($case.minDurationMs) | $($case.avgDurationMs) | $($case.maxDurationMs) | $($case.variabilityRatio) |"
}

$mdLines += @(
  '',
  '### Room Gate',
  '| Case | MinMs | AvgMs | MaxMs | Variability |',
  '|---|---:|---:|---:|---:|'
)

foreach ($case in $roomDrift.topCases) {
  $mdLines += "| $($case.caseId) | $($case.minDurationMs) | $($case.avgDurationMs) | $($case.maxDurationMs) | $($case.variabilityRatio) |"
}

$mdLines += @(
  '',
  '## Notes',
  "- Decision policy: releaseCandidateVerdict must be PASS to release.",
  "- Confidence policy: tier0, tier1, and room stability all contribute to the score.",
  "- Classification: failure_classification_v1",
  "- Regression: run_regression_v1",
  "- PreLaunch: pre_launch_score_v1",
  "- Model: rc_confidence_v3"
)

$mdDir = Split-Path -Path $MarkdownOutputPath -Parent
if (-not (Test-Path $mdDir)) {
  New-Item -Path $mdDir -ItemType Directory | Out-Null
}

$mdLines -join "`n" | Out-File -FilePath $MarkdownOutputPath -Encoding utf8

Write-Host "Release verdict written: $OutputPath"
Write-Host "Immutable verdict event written: $historyFilePath"
Write-Host "Verdict history index updated: $HistoryIndexPath"
Write-Host "Release markdown summary written: $MarkdownOutputPath"
Write-Host "Verdict: $($verdict.releaseCandidateVerdict)"

if (-not $releasePass) {
  exit 1
}

exit 0