param(
  [string]$DashboardPath = 'tools/reports/confidence_drift_dashboard.json',
  [string]$GovernorDecisionPath = 'tools/reports/release_governor_decision.json',
  [string]$ActivePolicyPath = 'tools/release_governor_policy.json',
  [string]$SafetyFloorsPath = 'tools/release_governor_safety_floors.json',
  [string]$ContractVersion = '1.0.0',
  [int]$WindowSize = 10,
  [int]$BaselineWindowSize = 30,
  [int]$BurnInRcCount = 6,
  [double]$DivergenceThreshold = 8,
  [bool]$EarlyExitOnSevereInstability = $true,
  [double]$ShortWeight = 0.4,
  [double]$BaselineWeight = 0.6,
  [string]$OutputProposedPath = 'tools/reports/proposed_thresholds.json',
  [string]$OutputSnapshotPath = 'tools/reports/rc_policy_snapshot_v1.json',
  [string]$OutputApprovalRequestPath = 'tools/reports/policy_approval_request.json',
  [string]$OutputStatusPath = 'tools/reports/policy_tuner_status.json',
  [string]$OutputHistoryIndexPath = 'tools/reports/policy_history_index.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Get-Slope {
  param([double[]]$Series)

  if ($Series.Count -lt 2) {
    return 0
  }

  $n = [double]$Series.Count
  $sumX = 0.0
  $sumY = 0.0
  $sumXY = 0.0
  $sumX2 = 0.0

  for ($i = 0; $i -lt $Series.Count; $i++) {
    $x = [double]$i
    $y = [double]$Series[$i]
    $sumX += $x
    $sumY += $y
    $sumXY += ($x * $y)
    $sumX2 += ($x * $x)
  }

  $den = ($n * $sumX2) - ($sumX * $sumX)
  if ($den -eq 0) {
    return 0
  }

  return [math]::Round((($n * $sumXY) - ($sumX * $sumY)) / $den, 4)
}

function Get-StdDev {
  param([double[]]$Series)

  if ($Series.Count -le 1) {
    return 0
  }

  $avg = ($Series | Measure-Object -Average).Average
  $sumSq = 0.0
  foreach ($v in $Series) {
    $d = $v - $avg
    $sumSq += ($d * $d)
  }

  return [math]::Round([math]::Sqrt($sumSq / $Series.Count), 4)
}

function Clamp {
  param(
    [double]$Value,
    [double]$Min,
    [double]$Max
  )

  return [math]::Max($Min, [math]::Min($Max, $Value))
}

if (-not (Test-Path $DashboardPath)) { throw "Dashboard not found: $DashboardPath" }
if (-not (Test-Path $ActivePolicyPath)) { throw "Active policy not found: $ActivePolicyPath" }
if (-not (Test-Path $SafetyFloorsPath)) { throw "Safety floors not found: $SafetyFloorsPath" }

$dashboard = Get-Content -Raw -Path $DashboardPath | ConvertFrom-Json
$activePolicy = Get-Content -Raw -Path $ActivePolicyPath | ConvertFrom-Json
$safetyFloors = Get-Content -Raw -Path $SafetyFloorsPath | ConvertFrom-Json
$decision = if (Test-Path $GovernorDecisionPath) { Get-Content -Raw -Path $GovernorDecisionPath | ConvertFrom-Json } else { $null }


if ($null -ne $activePolicy.tuner) {
  if ($PSBoundParameters.ContainsKey('ContractVersion') -eq $false -and $null -ne $activePolicy.contract) {
    $ContractVersion = [string]$activePolicy.contract.contract_version
  }
  if ($PSBoundParameters.ContainsKey('WindowSize') -eq $false) {
    $WindowSize = [int](Get-Numeric -Value $activePolicy.tuner.shortWindowSize -Default $WindowSize)
  }
  if ($PSBoundParameters.ContainsKey('BaselineWindowSize') -eq $false) {
    $BaselineWindowSize = [int](Get-Numeric -Value $activePolicy.tuner.baselineWindowSize -Default $BaselineWindowSize)
  }
  if ($PSBoundParameters.ContainsKey('BurnInRcCount') -eq $false) {
    $BurnInRcCount = [int](Get-Numeric -Value $activePolicy.tuner.burnInRcCount -Default $BurnInRcCount)
  }
  if ($PSBoundParameters.ContainsKey('DivergenceThreshold') -eq $false) {
    $DivergenceThreshold = Get-Numeric -Value $activePolicy.tuner.divergenceThreshold -Default $DivergenceThreshold
  }
  if ($PSBoundParameters.ContainsKey('EarlyExitOnSevereInstability') -eq $false) {
    $EarlyExitOnSevereInstability = [bool]$activePolicy.tuner.earlyExitOnSevereInstability
  }
  if ($PSBoundParameters.ContainsKey('ShortWeight') -eq $false) {
    $ShortWeight = Get-Numeric -Value $activePolicy.tuner.shortWeight -Default $ShortWeight
  }
  if ($PSBoundParameters.ContainsKey('BaselineWeight') -eq $false) {
    $BaselineWeight = Get-Numeric -Value $activePolicy.tuner.baselineWeight -Default $BaselineWeight
  }
}

$allRuns = @($dashboard.runs)
$runCount = $allRuns.Count
$shortRuns = @($allRuns | Select-Object -Last $WindowSize)
$baselineRuns = @($allRuns | Select-Object -Last $BaselineWindowSize)

$shortScores = @($shortRuns | ForEach-Object { Get-Numeric -Value $_.releaseConfidenceScore })
$baselineScores = @($baselineRuns | ForEach-Object { Get-Numeric -Value $_.releaseConfidenceScore })

$shortAvg = if ($shortScores.Count -gt 0) { [math]::Round((($shortScores | Measure-Object -Average).Average), 2) } else { 0 }
$baselineAvg = if ($baselineScores.Count -gt 0) { [math]::Round((($baselineScores | Measure-Object -Average).Average), 2) } else { 0 }

$shortStd = Get-StdDev -Series $shortScores
$baselineStd = Get-StdDev -Series $baselineScores

$shortSlope = Get-Slope -Series $shortScores
$baselineSlope = Get-Slope -Series $baselineScores

$weightDen = $ShortWeight + $BaselineWeight
if ($weightDen -le 0) {
  $ShortWeight = 0.5
  $BaselineWeight = 0.5
  $weightDen = 1
}

$blendAvg = [math]::Round(((($shortAvg * $ShortWeight) + ($baselineAvg * $BaselineWeight)) / $weightDen), 2)
$blendStd = [math]::Round(((($shortStd * $ShortWeight) + ($baselineStd * $BaselineWeight)) / $weightDen), 4)
$blendSlope = [math]::Round(((($shortSlope * $ShortWeight) + ($baselineSlope * $BaselineWeight)) / $weightDen), 4)
$policyDivergenceScore = [math]::Round([math]::Abs($shortAvg - $baselineAvg), 2)
$hasDivergence = ($policyDivergenceScore -gt $DivergenceThreshold)
$divergenceClassification = if (-not $hasDivergence) {
  'transient'
} elseif ($shortStd -gt ($baselineStd * 1.5) -or [math]::Abs($shortSlope) -gt ([math]::Abs($baselineSlope) + 0.4)) {
  'spike'
} else {
  'structural'
}

$isBurnIn = ($runCount -lt $BurnInRcCount)
$failedTier0Runs = [int](Get-Numeric -Value $dashboard.gateStability.failedTier0Runs)
$failedTier1Runs = [int](Get-Numeric -Value $dashboard.gateStability.failedTier1Runs)
$latestVerdict = [string]$dashboard.summary.latestVerdict
$latestDecision = if ($null -ne $decision) { [string]$decision.governanceDecision } else { 'UNKNOWN' }
$severeInstability = ($latestVerdict -ne 'PASS' -or $latestDecision -eq 'BLOCK' -or $failedTier0Runs -gt 0 -or $failedTier1Runs -gt 0)
$burnInOverrideTriggered = ($isBurnIn -and $EarlyExitOnSevereInstability -and $severeInstability)
$effectiveBurnInFreeze = ($isBurnIn -and -not $burnInOverrideTriggered)

$currentConfidence = Get-Numeric -Value $activePolicy.confidenceThreshold
$currentSlopeBlock = Get-Numeric -Value $activePolicy.slopeBlockThreshold
$currentVarianceWarn = Get-Numeric -Value $activePolicy.varianceIncreaseWarningPercent

$recommendedConfidence = $currentConfidence
$recommendedSlopeBlock = $currentSlopeBlock
$recommendedVarianceWarn = $currentVarianceWarn
$recommendationType = 'hold'

if ($hasDivergence) {
  $recommendationType = 'stall_and_review'
} elseif (-not $effectiveBurnInFreeze) {
  $recommendationType = 'tune'
  $recommendedConfidence = [math]::Round((Clamp -Value ($blendAvg - [math]::Max(5, $blendStd)) -Min (Get-Numeric -Value $safetyFloors.minConfidenceThreshold) -Max 95), 2)

  if ($blendSlope -lt 0) {
    $recommendedSlopeBlock = [math]::Round([math]::Min($currentSlopeBlock, $blendSlope - 0.5), 2)
  }

  $recommendedVarianceWarn = [math]::Round((Clamp -Value ([math]::Max(20, 40 - ($blendStd * 2))) -Min 20 -Max 60), 2)
}

$recommended = [ordered]@{
  confidenceThreshold = $recommendedConfidence
  slopeBlockThreshold = $recommendedSlopeBlock
  varianceIncreaseWarningPercent = $recommendedVarianceWarn
}

$delta = [ordered]@{
  confidenceThreshold = [math]::Round(($recommendedConfidence - $currentConfidence), 2)
  slopeBlockThreshold = [math]::Round(($recommendedSlopeBlock - $currentSlopeBlock), 2)
  varianceIncreaseWarningPercent = [math]::Round(($recommendedVarianceWarn - $currentVarianceWarn), 2)
}

$hasThresholdDelta = ($delta.confidenceThreshold -ne 0 -or $delta.slopeBlockThreshold -ne 0 -or $delta.varianceIncreaseWarningPercent -ne 0)
$recommendationState = if ($effectiveBurnInFreeze) {
  'burn_in'
} elseif ($severeInstability) {
  'unstable'
} elseif ($hasDivergence) {
  'drifting'
} elseif ($hasThresholdDelta) {
  'stable'
} else {
  'hold'
}

$changeMagnitude = [math]::Round(
  [math]::Abs($delta.confidenceThreshold) +
  ([math]::Abs($delta.slopeBlockThreshold) * 10) +
  ([math]::Abs($delta.varianceIncreaseWarningPercent) / 2),
  4
)
$changeVolatility = [math]::Min(1, ($changeMagnitude / 20.0))
$divergencePenalty = [math]::Min(1, ($policyDivergenceScore / [math]::Max(1, ($DivergenceThreshold * 2))))
$passConsistency = if ($runCount -le 0) {
  0
} else {
  [math]::Max(0, 1 - (($failedTier0Runs + $failedTier1Runs) / (2.0 * $runCount)))
}
$policyStabilityScore = [math]::Round(
  [math]::Max(0, [math]::Min(1, (0.4 * $passConsistency) + (0.4 * (1 - $divergencePenalty)) + (0.2 * (1 - $changeVolatility)))),
  4
)

$justificationSignals = [ordered]@{
  runCount = $runCount
  shortWindowSize = $WindowSize
  baselineWindowSize = $BaselineWindowSize
  burnInRcCount = $BurnInRcCount
  inBurnInFreeze = $effectiveBurnInFreeze
  burnInOverrideTriggered = $burnInOverrideTriggered
  earlyExitOnSevereInstability = $EarlyExitOnSevereInstability
  policy_divergence_score = $policyDivergenceScore
  divergenceThreshold = $DivergenceThreshold
  divergenceDetected = $hasDivergence
  divergenceClassification = $divergenceClassification
  changeMagnitude = $changeMagnitude
  passConsistency = [math]::Round($passConsistency, 4)
  policy_stability_score = $policyStabilityScore
  severeInstability = $severeInstability
  shortWindow = [ordered]@{
    scoreAverage = $shortAvg
    scoreStdDev = $shortStd
    scoreSlope = $shortSlope
  }
  baselineWindow = [ordered]@{
    scoreAverage = $baselineAvg
    scoreStdDev = $baselineStd
    scoreSlope = $baselineSlope
  }
  blended = [ordered]@{
    shortWeight = $ShortWeight
    baselineWeight = $BaselineWeight
    scoreAverage = $blendAvg
    scoreStdDev = $blendStd
    scoreSlope = $blendSlope
  }
  latestVolatilityBand = $dashboard.summary.volatilityBand
  latestGovernanceDecision = $latestDecision
  sampleAwareMode = ($runCount -lt [int]$activePolicy.minimumSamplesForTrendRules)
}

$proposed = [ordered]@{
  contract_version = $ContractVersion
  artifact_mode = 'primary'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  modelVersion = 'policy_tuner_v1'
  mode = 'recommend-only'
  recommendationType = $recommendationType
  recommendationState = $recommendationState
  policy_divergence_score = $policyDivergenceScore
  divergence_classification = $divergenceClassification
  policy_stability_score = $policyStabilityScore
  currentThresholds = [ordered]@{
    confidenceThreshold = $currentConfidence
    slopeBlockThreshold = $currentSlopeBlock
    varianceIncreaseWarningPercent = $currentVarianceWarn
  }
  recommendedThresholds = $recommended
  delta = $delta
  safetyFloors = $safetyFloors
  justificationSignals = $justificationSignals
}

$snapshot = [ordered]@{
  contract_version = $ContractVersion
  artifact_mode = 'primary'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  snapshotVersion = 'rc_policy_snapshot_v1'
  mode = 'recommend-only'
  activePolicyPath = $ActivePolicyPath
  safetyFloorsPath = $SafetyFloorsPath
  dashboardPath = $DashboardPath
  governorDecisionPath = $GovernorDecisionPath
  currentPolicy = $activePolicy
  proposedPolicy = $proposed
}

$approvalRequest = [ordered]@{
  contract_version = $ContractVersion
  artifact_mode = 'primary'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  requestVersion = 'policy_approval_request_v1'
  status = 'pending_manual_approval'
  mode = 'recommend-only'
  recommendationType = $recommendationType
  recommendationState = $recommendationState
  policy_stability_score = $policyStabilityScore
  proposedThresholdsPath = $OutputProposedPath
  snapshotPath = $OutputSnapshotPath
  approvalRequired = $true
  approvalNotes = 'Review delta and justification signals; approve promotion in a separate manual process.'
}

$status = [ordered]@{
  contract_version = $ContractVersion
  artifact_mode = 'primary'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  statusVersion = 'policy_tuner_status_v1'
  status = 'ok'
  policyAction = 'hold'
  mode = 'recommend-only'
  recommendationType = $recommendationType
  recommendationState = $recommendationState
  policy_divergence_score = $policyDivergenceScore
  divergence_classification = $divergenceClassification
  policy_stability_score = $policyStabilityScore
  inBurnInFreeze = $effectiveBurnInFreeze
  runCount = $runCount
  burnInRcCount = $BurnInRcCount
  outputs = [ordered]@{
    proposedThresholdsPath = $OutputProposedPath
    snapshotPath = $OutputSnapshotPath
    approvalRequestPath = $OutputApprovalRequestPath
  }
}

$historyIndex = if (Test-Path $OutputHistoryIndexPath) {
  Get-Content -Raw -Path $OutputHistoryIndexPath | ConvertFrom-Json
} else {
  [PSCustomObject]@{
    contract_version = $ContractVersion
    artifact_mode = 'primary'
    indexVersion = 'policy_history_index_v1'
    entries = @()
  }
}

$entries = @($historyIndex.entries)
$entries += [PSCustomObject]@{
  timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
  eventType = 'proposal'
  policyVersion = $activePolicy.modelVersion
  changeMagnitude = $changeMagnitude
  recommendationType = $recommendationType
  recommendationState = $recommendationState
  divergenceScore = $policyDivergenceScore
  divergenceClassification = $divergenceClassification
  policyStabilityScore = $policyStabilityScore
  rcContext = [PSCustomObject]@{
    runCount = $runCount
    latestVerdict = $latestVerdict
    latestGovernanceDecision = $latestDecision
    inBurnInFreeze = $effectiveBurnInFreeze
  }
}
$historyIndex.entries = $entries

$outDir = Split-Path -Path $OutputProposedPath -Parent
if (-not (Test-Path $outDir)) {
  New-Item -Path $outDir -ItemType Directory | Out-Null
}

$proposed | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputProposedPath -Encoding utf8
$snapshot | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputSnapshotPath -Encoding utf8
$approvalRequest | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputApprovalRequestPath -Encoding utf8
$status | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputStatusPath -Encoding utf8
$historyIndex | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputHistoryIndexPath -Encoding utf8

Write-Host "Proposed thresholds written: $OutputProposedPath"
Write-Host "Policy snapshot written: $OutputSnapshotPath"
Write-Host "Policy approval request written: $OutputApprovalRequestPath"
Write-Host "Policy tuner status written: $OutputStatusPath"
Write-Host "Policy history index written: $OutputHistoryIndexPath"