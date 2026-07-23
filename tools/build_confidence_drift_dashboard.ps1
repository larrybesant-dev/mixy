param(
  [string]$ReportsDir = 'tools/reports',
  [string]$HistoryDir = 'tools/reports/history',
  [string]$VerdictPattern = 'release_candidate_verdict*.json',
  [string]$OutputJson = 'tools/reports/confidence_drift_dashboard.json',
  [string]$OutputMarkdown = 'tools/reports/confidence_drift_dashboard.md',
  [switch]$PreferHistory
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

function Get-IsoTimeOrNow {
  param([object]$Value)

  if ($null -eq $Value) {
    return (Get-Date).ToUniversalTime()
  }

  try {
    return ([datetime]$Value).ToUniversalTime()
  } catch {
    return (Get-Date).ToUniversalTime()
  }
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

if (-not (Test-Path $ReportsDir)) {
  throw "Reports directory not found: $ReportsDir"
}

$files = @()

if ($PreferHistory.IsPresent -and (Test-Path $HistoryDir)) {
  $historyFiles = @(Get-ChildItem -Path $HistoryDir -Filter $VerdictPattern -File | Where-Object { $_.Name -notlike '*.md' })
  if ($historyFiles.Count -gt 0) {
    $files = $historyFiles
  }
}

if ($files.Count -eq 0) {
  $files = @(Get-ChildItem -Path $ReportsDir -Filter $VerdictPattern -File | Where-Object { $_.Name -notlike '*.md' })
}

if ($files.Count -eq 0) {
  throw "No verdict files found in $ReportsDir or $HistoryDir matching pattern: $VerdictPattern"
}

$runs = @()
foreach ($file in $files) {
  $raw = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json

  $timestamp = Get-IsoTimeOrNow -Value $raw.generatedAtUtc
  $score = Get-Numeric -Value $raw.releaseConfidenceScore
  $band = if ($raw.releaseConfidenceBand) { $raw.releaseConfidenceBand } else { 'unknown' }
  $verdict = if ($raw.releaseCandidateVerdict) { $raw.releaseCandidateVerdict } else { 'UNKNOWN' }

  $tier0 = @($raw.gates | Where-Object { $_.gate -eq 'tier0' } | Select-Object -First 1)
  $tier1 = @($raw.gates | Where-Object { $_.gate -eq 'tier1' } | Select-Object -First 1)

  $tier0Pass = if ($tier0.Count -gt 0) { [bool]$tier0[0].pass } else { $false }
  $tier1Pass = if ($tier1.Count -gt 0) { [bool]$tier1[0].pass } else { $false }

  $tier0Drift = @($raw.gateScores | Where-Object { $_.gate -eq 'tier0' } | Select-Object -First 1)
  $tier1Drift = @($raw.gateScores | Where-Object { $_.gate -eq 'tier1' } | Select-Object -First 1)

  $tier0AvgVar = if ($tier0Drift.Count -gt 0) { Get-Numeric -Value $tier0Drift[0].drift.averageVariabilityRatio } else { 0 }
  $tier1AvgVar = if ($tier1Drift.Count -gt 0) { Get-Numeric -Value $tier1Drift[0].drift.averageVariabilityRatio } else { 0 }

  $runs += [PSCustomObject]@{
    file = $file.Name
    generatedAtUtc = $timestamp.ToString('o')
    releaseVerdict = $verdict
    releaseConfidenceScore = [math]::Round($score, 2)
    releaseConfidenceBand = $band
    tier0Pass = $tier0Pass
    tier1Pass = $tier1Pass
    tier0AvgVariability = [math]::Round($tier0AvgVar, 4)
    tier1AvgVariability = [math]::Round($tier1AvgVar, 4)
  }
}

$runs = @($runs | Sort-Object generatedAtUtc)

$scores = @($runs | ForEach-Object { [double]$_.releaseConfidenceScore })
$latest = $runs[-1]
$previous = if ($runs.Count -gt 1) { $runs[-2] } else { $null }
$delta = if ($null -eq $previous) { 0 } else { [math]::Round(($latest.releaseConfidenceScore - $previous.releaseConfidenceScore), 2) }

$stdDev = Get-StdDev -Series $scores
$slope = Get-Slope -Series $scores
$avgScore = [math]::Round((($scores | Measure-Object -Average).Average), 2)
$minScore = [math]::Round((($scores | Measure-Object -Minimum).Minimum), 2)
$maxScore = [math]::Round((($scores | Measure-Object -Maximum).Maximum), 2)

$bandCounts = [ordered]@{
  very_high = @($runs | Where-Object { $_.releaseConfidenceBand -eq 'very_high' }).Count
  high = @($runs | Where-Object { $_.releaseConfidenceBand -eq 'high' }).Count
  moderate = @($runs | Where-Object { $_.releaseConfidenceBand -eq 'moderate' }).Count
  low = @($runs | Where-Object { $_.releaseConfidenceBand -eq 'low' }).Count
}

$failedTier0 = @($runs | Where-Object { -not $_.tier0Pass }).Count
$failedTier1 = @($runs | Where-Object { -not $_.tier1Pass }).Count

$dashboard = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  modelVersion = 'confidence_drift_dashboard_v1'
  source = [ordered]@{
    reportsDirectory = $ReportsDir
    historyDirectory = $HistoryDir
    preferHistory = $PreferHistory.IsPresent
    verdictPattern = $VerdictPattern
    verdictCount = $runs.Count
  }
  summary = [ordered]@{
    latestScore = $latest.releaseConfidenceScore
    latestBand = $latest.releaseConfidenceBand
    latestVerdict = $latest.releaseVerdict
    scoreDeltaFromPrevious = $delta
    averageScore = $avgScore
    minScore = $minScore
    maxScore = $maxScore
    scoreStdDev = $stdDev
    trendSlopePerRun = $slope
    volatilityBand = Get-VolatilityBand -StdDev $stdDev
  }
  gateStability = [ordered]@{
    failedTier0Runs = $failedTier0
    failedTier1Runs = $failedTier1
  }
  confidenceBandDistribution = $bandCounts
  runs = $runs
}

$outJsonDir = Split-Path -Path $OutputJson -Parent
if (-not (Test-Path $outJsonDir)) {
  New-Item -Path $outJsonDir -ItemType Directory | Out-Null
}

$dashboard | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputJson -Encoding utf8

$lines = @(
  '# Confidence Drift Dashboard',
  '',
  "- GeneratedAtUtc: $($dashboard.generatedAtUtc)",
  "- VerdictCount: $($dashboard.source.verdictCount)",
  "- LatestScore: $($dashboard.summary.latestScore)",
  "- LatestBand: $($dashboard.summary.latestBand)",
  "- LatestVerdict: $($dashboard.summary.latestVerdict)",
  "- DeltaFromPrevious: $($dashboard.summary.scoreDeltaFromPrevious)",
  "- AverageScore: $($dashboard.summary.averageScore)",
  "- ScoreRange: $($dashboard.summary.minScore) to $($dashboard.summary.maxScore)",
  "- ScoreStdDev: $($dashboard.summary.scoreStdDev)",
  "- TrendSlopePerRun: $($dashboard.summary.trendSlopePerRun)",
  "- VolatilityBand: $($dashboard.summary.volatilityBand)",
  "- FailedTier0Runs: $($dashboard.gateStability.failedTier0Runs)",
  "- FailedTier1Runs: $($dashboard.gateStability.failedTier1Runs)",
  '',
  '## Confidence Band Distribution',
  '',
  '| Band | Count |',
  '|---|---:|',
  "| very_high | $($dashboard.confidenceBandDistribution.very_high) |",
  "| high | $($dashboard.confidenceBandDistribution.high) |",
  "| moderate | $($dashboard.confidenceBandDistribution.moderate) |",
  "| low | $($dashboard.confidenceBandDistribution.low) |",
  '',
  '## Run Trend',
  '',
  '| Time (UTC) | Verdict | Score | Band | Tier0 | Tier1 | Tier0 AvgVar | Tier1 AvgVar | Source |',
  '|---|---|---:|---|---:|---:|---:|---:|---|'
)

foreach ($run in $runs) {
  $lines += "| $($run.generatedAtUtc) | $($run.releaseVerdict) | $($run.releaseConfidenceScore) | $($run.releaseConfidenceBand) | $($run.tier0Pass) | $($run.tier1Pass) | $($run.tier0AvgVariability) | $($run.tier1AvgVariability) | $($run.file) |"
}

$outMdDir = Split-Path -Path $OutputMarkdown -Parent
if (-not (Test-Path $outMdDir)) {
  New-Item -Path $outMdDir -ItemType Directory | Out-Null
}

$lines -join "`n" | Out-File -FilePath $OutputMarkdown -Encoding utf8

Write-Host "Confidence drift dashboard JSON written: $OutputJson"
Write-Host "Confidence drift dashboard Markdown written: $OutputMarkdown"