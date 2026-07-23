<#
.SYNOPSIS
  Analyzes how burn-in decision boundaries move as history depth increases.

.DESCRIPTION
  Side-effect free analysis tool. It reads the immutable verdict index and,
  for each history prefix length, computes the burn-in threshold boundary over
  a sweep range.

  Output answers:
    - how firstExitThreshold changes as more RC events accumulate
    - how lastFrozenThreshold changes as more RC events accumulate
    - whether the boundary is stable, drifting, or not yet formed

.PARAMETER IndexPath
  Path to verdict history index JSON.

.PARAMETER SweepBurnInFrom
  Inclusive start of burn-in threshold sweep.

.PARAMETER SweepBurnInTo
  Inclusive end of burn-in threshold sweep.

.PARAMETER OutputPath
  Optional output file path. If omitted, JSON is written to stdout only.
#>
param(
  [string]$IndexPath = 'tools/reports/history/verdict_index.json',
  [int]$SweepBurnInFrom = 1,
  [int]$SweepBurnInTo = 10,
  [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-IsoTimeOrNow {
  param([object]$Value)
  if ($null -eq $Value) { return (Get-Date).ToUniversalTime() }
  try { return ([datetime]$Value).ToUniversalTime() } catch { return (Get-Date).ToUniversalTime() }
}

if ($SweepBurnInFrom -lt 1) {
  throw 'SweepBurnInFrom must be >= 1'
}

if ($SweepBurnInTo -lt $SweepBurnInFrom) {
  throw 'SweepBurnInTo must be >= SweepBurnInFrom'
}

if (-not (Test-Path $IndexPath)) {
  throw "Verdict index not found: $IndexPath"
}

$raw = Get-Content -Path $IndexPath -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
  throw "Verdict index is empty: $IndexPath"
}

$entries = @($raw | ConvertFrom-Json)
if ($entries.Count -eq 0) {
  throw "Verdict index has no entries: $IndexPath"
}

$orderedEntries = @(
  $entries | Sort-Object `
    @{ Expression = { Get-IsoTimeOrNow -Value $_.generatedAtUtc } ; Ascending = $true }, `
    @{ Expression = { [string]$_.runId } ; Ascending = $true }, `
    @{ Expression = { [string]$_.file } ; Ascending = $true }
)

function Get-BoundarySnapshot {
  param(
    [int]$EntryCount,
    [int]$SweepFrom,
    [int]$SweepTo
  )

  $exitThresholds = @()
  $frozenThresholds = @()

  for ($threshold = $SweepFrom; $threshold -le $SweepTo; $threshold++) {
    if ($EntryCount -ge $threshold) {
      $exitThresholds += $threshold
    } else {
      $frozenThresholds += $threshold
    }
  }

  $firstExitThreshold = if ($exitThresholds.Count -gt 0) { ($exitThresholds | Select-Object -First 1) } else { $null }
  $lastFrozenThreshold = if ($frozenThresholds.Count -gt 0) { ($frozenThresholds | Select-Object -Last 1) } else { $null }

  return [ordered]@{
    entryCount = $EntryCount
    firstExitThreshold = $firstExitThreshold
    lastFrozenThreshold = $lastFrozenThreshold
    exitThresholdCount = $exitThresholds.Count
    frozenThresholdCount = $frozenThresholds.Count
    boundaryFormed = ($null -ne $firstExitThreshold -and $null -ne $lastFrozenThreshold)
    exitThresholds = $exitThresholds
    frozenThresholds = $frozenThresholds
  }
}

$prefixSnapshots = @()
for ($count = 1; $count -le $orderedEntries.Count; $count++) {
  $snapshot = Get-BoundarySnapshot -EntryCount $count -SweepFrom $SweepBurnInFrom -SweepTo $SweepBurnInTo
  $prefixSnapshots += [ordered]@{
    historyDepth = $count
    firstExitThreshold = $snapshot.firstExitThreshold
    lastFrozenThreshold = $snapshot.lastFrozenThreshold
    boundaryFormed = $snapshot.boundaryFormed
    exitThresholdCount = $snapshot.exitThresholdCount
    frozenThresholdCount = $snapshot.frozenThresholdCount
  }
}

$firstExitSeries = @($prefixSnapshots | ForEach-Object { if ($null -eq $_.firstExitThreshold) { 'null' } else { [string]$_.firstExitThreshold } })
$lastFrozenSeries = @($prefixSnapshots | ForEach-Object { if ($null -eq $_.lastFrozenThreshold) { 'null' } else { [string]$_.lastFrozenThreshold } })
$distinctFirstExit = @($firstExitSeries | Sort-Object -Unique)
$distinctLastFrozen = @($lastFrozenSeries | Sort-Object -Unique)

$boundaryBehavior = if ($orderedEntries.Count -le 1) {
  'insufficient_history'
} elseif ($distinctFirstExit.Count -eq 1 -and $distinctLastFrozen.Count -eq 1) {
  'stable'
} else {
  'drifting'
}

$result = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  analysisVersion = 'policy_boundary_drift_v1'
  schemaVersion = '1.0.0'
  source = [ordered]@{
    indexPath = $IndexPath
    entryCount = $orderedEntries.Count
  }
  parameters = [ordered]@{
    sweepBurnInFrom = $SweepBurnInFrom
    sweepBurnInTo = $SweepBurnInTo
  }
  summary = [ordered]@{
    boundaryBehavior = $boundaryBehavior
    distinctFirstExitThresholds = $distinctFirstExit
    distinctLastFrozenThresholds = $distinctLastFrozen
    latestFirstExitThreshold = $prefixSnapshots[-1].firstExitThreshold
    latestLastFrozenThreshold = $prefixSnapshots[-1].lastFrozenThreshold
  }
  prefixes = $prefixSnapshots
}

$json = $result | ConvertTo-Json -Depth 20

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outDir = Split-Path -Path $OutputPath -Parent
  if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
    New-Item -Path $outDir -ItemType Directory | Out-Null
  }
  $json | Out-File -FilePath $OutputPath -Encoding utf8
}

Write-Output $json
