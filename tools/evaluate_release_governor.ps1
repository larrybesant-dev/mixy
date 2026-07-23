param(
  [string]$DashboardPath = 'tools/reports/confidence_drift_dashboard.json',
  [string]$PolicyPath = 'tools/release_governor_policy.json',
  [string]$OutputJson = 'tools/reports/release_governor_decision.json',
  [string]$OutputMarkdown = 'tools/reports/release_governor_decision.md'
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

function Get-VolatilityBand {
  param([double]$StdDev)

  if ($StdDev -le 3) { return 'stable' }
  if ($StdDev -le 8) { return 'moderate' }
  return 'volatile'
}

function Add-Decision {
  param(
    [System.Collections.ArrayList]$Decisions,
    [string]$Id,
    [string]$Severity,
    [bool]$Triggered,
    [string]$MessageModel,
    [string]$Metric
  )

  [void]$Decisions.Add([PSCustomObject]@{
    id = $Id
    severity = $Severity
    triggered = $Triggered
    metric = $Metric
    MessageModel = $MessageModel
  })
}

if (-not (Test-Path $DashboardPath)) {
  throw "Dashboard not found: $DashboardPath"
}
if (-not (Test-Path $PolicyPath)) {
  throw "Policy not found: $PolicyPath"
}

$dashboard = Get-Content -Raw -Path $DashboardPath | ConvertFrom-Json
$policy = Get-Content -Raw -Path $PolicyPath | ConvertFrom-Json

$runs = @($dashboard.runs)
if ($runs.Count -eq 0) {
  throw 'Dashboard contains no runs.'
}

$minSamples = [int]$policy.minimumSamplesForTrendRules
$window = [int]$policy.recentWindowSize
$latest = $runs[-1]

$scores = @($runs | ForEach-Object { Get-Numeric -Value $_.releaseConfidenceScore })
$recentRuns = @($runs | Select-Object -Last $window)
$recentScores = @($recentRuns | ForEach-Object { Get-Numeric -Value $_.releaseConfidenceScore })
$recentSlope = Get-Slope -Series $recentScores
$recentStdDev = Get-StdDev -Series $recentScores
$recentBand = Get-VolatilityBand -StdDev $recentStdDev

$previousRuns = @()
if ($runs.Count -ge ($window * 2)) {
  $start = $runs.Count - ($window * 2)
  $previousRuns = @($runs[$start..($start + $window - 1)])
}

$previousScores = @($previousRuns | ForEach-Object { Get-Numeric -Value $_.releaseConfidenceScore })
$previousStdDev = if ($previousScores.Count -gt 0) { Get-StdDev -Series $previousScores } else { 0 }
$previousBand = if ($previousScores.Count -gt 0) { Get-VolatilityBand -StdDev $previousStdDev } else { 'unknown' }

$decisions = New-Object System.Collections.ArrayList

$latestVerdictFail = ($latest.releaseVerdict -ne 'PASS')
Add-Decision -Decisions $decisions -Id 'GV-H1' -Severity 'hard' -Triggered $latestVerdictFail -Metric "latestVerdict=$($latest.releaseVerdict)" -MessageModel 'Block when latest release verdict is FAIL.'

$insufficientSamples = ($runs.Count -lt $minSamples)

$slopeBlocked = $false
if (-not $insufficientSamples -and $recentScores.Count -ge 2) {
  $slopeBlocked = ($recentSlope -lt [double]$policy.slopeBlockThreshold)
}
Add-Decision -Decisions $decisions -Id 'GV-H2' -Severity 'hard' -Triggered $slopeBlocked -Metric "recentSlope=$recentSlope threshold=$($policy.slopeBlockThreshold)" -MessageModel 'Block on sustained negative confidence slope in recent window.'

$volatilityBlocked = $false
$targetBands = @($policy.volatilityEscalationBlock.to)
if (-not $insufficientSamples -and $previousScores.Count -gt 0) {
  $volatilityBlocked = (($previousBand -eq $policy.volatilityEscalationBlock.from) -and ($targetBands -contains $recentBand))
}
Add-Decision -Decisions $decisions -Id 'GV-H3' -Severity 'hard' -Triggered $volatilityBlocked -Metric "previousBand=$previousBand recentBand=$recentBand" -MessageModel 'Block on volatility escalation from stable to moderate/volatile.'

$lowThreshold = [double]$policy.confidenceThreshold
$consecutiveLowLimit = [int]$policy.consecutiveLowConfidenceToBlock
$consecutiveLow = 0
for ($i = $runs.Count - 1; $i -ge 0; $i--) {
  if ((Get-Numeric -Value $runs[$i].releaseConfidenceScore) -lt $lowThreshold) {
    $consecutiveLow++
  } else {
    break
  }
}
$lowConfidenceBlocked = (-not $insufficientSamples) -and ($consecutiveLow -ge $consecutiveLowLimit)
Add-Decision -Decisions $decisions -Id 'GV-H4' -Severity 'hard' -Triggered $lowConfidenceBlocked -Metric "consecutiveLow=$consecutiveLow threshold=$consecutiveLowLimit limitScore=$lowThreshold" -MessageModel 'Block on consecutive low-confidence runs.'

$varianceWarning = $false
$varianceIncreasePct = 0.0
if ($previousScores.Count -gt 0) {
  if ($previousStdDev -gt 0) {
    $varianceIncreasePct = [math]::Round((($recentStdDev - $previousStdDev) / $previousStdDev) * 100, 2)
  } elseif ($recentStdDev -gt 0) {
    $varianceIncreasePct = 100
  }
  $varianceWarning = ($varianceIncreasePct -ge [double]$policy.varianceIncreaseWarningPercent)
}
Add-Decision -Decisions $decisions -Id 'GV-W1' -Severity 'warning' -Triggered $varianceWarning -Metric "varianceIncreasePct=$varianceIncreasePct threshold=$($policy.varianceIncreaseWarningPercent)" -MessageModel 'Warn when confidence variance increases significantly vs baseline window.'

$confidenceDropWarn = $false
$delta = Get-Numeric -Value $dashboard.summary.scoreDeltaFromPrevious
$latestTierPass = ([bool]$latest.tier0Pass -and [bool]$latest.tier1Pass)
if ($latestTierPass) {
  $confidenceDropWarn = ($delta -le -1 * [double]$policy.confidenceDropWarningThreshold)
}
Add-Decision -Decisions $decisions -Id 'GV-W2' -Severity 'warning' -Triggered $confidenceDropWarn -Metric "delta=$delta threshold=-$($policy.confidenceDropWarningThreshold) latestTierPass=$latestTierPass" -MessageModel 'Warn when confidence drops despite Tier 0 and Tier 1 passing.'

$sampleNotice = $insufficientSamples
Add-Decision -Decisions $decisions -Id 'GV-I1' -Severity 'info' -Triggered $sampleNotice -Metric "runCount=$($runs.Count) minRequired=$minSamples" -MessageModel 'Trend hard-rules are observation-only until minimum sample size is reached.'

$hardTriggered = @($decisions | Where-Object { $_.severity -eq 'hard' -and $_.triggered }).Count
$warningTriggered = @($decisions | Where-Object { $_.severity -eq 'warning' -and $_.triggered }).Count

$governorDecision = if ($hardTriggered -gt 0) { 'BLOCK' } else { 'ALLOW' }

$result = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  policyVersion = $policy.modelVersion
  dashboardSource = $DashboardPath
  governanceDecision = $governorDecision
  runCount = $runs.Count
  recentWindowSize = $window
  recentTrend = [ordered]@{
    slope = $recentSlope
    stdDev = $recentStdDev
    volatilityBand = $recentBand
    previousWindowStdDev = $previousStdDev
    previousWindowVolatilityBand = $previousBand
    varianceIncreasePercent = [math]::Round($varianceIncreasePct, 2)
  }
  latest = [ordered]@{
    generatedAtUtc = $latest.generatedAtUtc
    releaseVerdict = $latest.releaseVerdict
    releaseConfidenceScore = $latest.releaseConfidenceScore
    releaseConfidenceBand = $latest.releaseConfidenceBand
    tier0Pass = [bool]$latest.tier0Pass
    tier1Pass = [bool]$latest.tier1Pass
  }
  counts = [ordered]@{
    hardTriggered = $hardTriggered
    warningTriggered = $warningTriggered
  }
  decisions = $decisions
}

$outJsonDir = Split-Path -Path $OutputJson -Parent
if (-not (Test-Path $outJsonDir)) {
  New-Item -Path $outJsonDir -ItemType Directory | Out-Null
}

$result | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputJson -Encoding utf8

$md = @(
  '# Release Governor Decision',
  '',
  "- GeneratedAtUtc: $($result.generatedAtUtc)",
  "- GovernanceDecision: $($result.governanceDecision)",
  "- PolicyVersion: $($result.policyVersion)",
  "- RunCount: $($result.runCount)",
  "- RecentWindowSize: $($result.recentWindowSize)",
  "- RecentSlope: $($result.recentTrend.slope)",
  "- RecentStdDev: $($result.recentTrend.stdDev)",
  "- RecentVolatilityBand: $($result.recentTrend.volatilityBand)",
  "- PreviousVolatilityBand: $($result.recentTrend.previousWindowVolatilityBand)",
  "- VarianceIncreasePercent: $($result.recentTrend.varianceIncreasePercent)",
  '',
  '## Rule Outcomes',
  '',
  '| Rule | Severity | Triggered | Metric | MessageModel |',
  '|---|---|---:|---|---|'
)

foreach ($d in $decisions) {
  $md += "| $($d.id) | $($d.severity) | $($d.triggered) | $($d.metric) | $($d.MessageModel) |"
}

$outMdDir = Split-Path -Path $OutputMarkdown -Parent
if (-not (Test-Path $outMdDir)) {
  New-Item -Path $outMdDir -ItemType Directory | Out-Null
}

$md -join "`n" | Out-File -FilePath $OutputMarkdown -Encoding utf8

Write-Host "Release governor JSON written: $OutputJson"
Write-Host "Release governor Markdown written: $OutputMarkdown"
Write-Host "Governance decision: $governorDecision"

if ($governorDecision -eq 'BLOCK') {
  exit 1
}