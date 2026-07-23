<#
.SYNOPSIS
  Deterministically replays governance timeline progression from verdict history index.

.DESCRIPTION
  This tool is side-effect free by default. It reads an immutable verdict index,
  reconstructs ordered runs, and simulates runCount/burn-in progression.

  It does not mutate policy, tuner, dashboard, or CI artifacts.

.PARAMETER IndexPath
  Path to verdict history index JSON.

.PARAMETER BurnInRcCount
  Burn-in threshold to simulate. Defaults to current policy value (6).

.PARAMETER SweepBurnInFrom
  Optional start burn-in threshold for sweep simulation.

.PARAMETER SweepBurnInTo
  Optional end burn-in threshold for sweep simulation (inclusive).

.PARAMETER AsJson
  Emit JSON (default behavior).

.PARAMETER OutputPath
  Optional path for writing replay output. If omitted, output is written to stdout only.

.EXAMPLE
  .\tools\replay_governance_timeline.ps1

.EXAMPLE
  .\tools\replay_governance_timeline.ps1 -BurnInRcCount 4

.EXAMPLE
  .\tools\replay_governance_timeline.ps1 -OutputPath tools/reports/replay_timeline.json
#>
param(
  [string]$IndexPath = 'tools/reports/history/verdict_index.json',
  [int]$BurnInRcCount = 6,
  [int]$SweepBurnInFrom = 0,
  [int]$SweepBurnInTo = 0,
  [switch]$AsJson,
  [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-IsoTimeOrNow {
  param([object]$Value)
  if ($null -eq $Value) { return (Get-Date).ToUniversalTime() }
  try { return ([datetime]$Value).ToUniversalTime() } catch { return (Get-Date).ToUniversalTime() }
}

function Get-Numeric {
  param(
    [object]$Value,
    [double]$Default = 0
  )

  if ($null -eq $Value) {
    return $Default
  }

  if ($Value -is [System.Array]) {
    if ($Value.Count -eq 0) {
      return $Default
    }
    $Value = $Value[0]
  }

  $parsed = 0.0
  if ([double]::TryParse([string]$Value, [ref]$parsed)) {
    return $parsed
  }

  return $Default
}

if ($BurnInRcCount -lt 1) {
  throw 'BurnInRcCount must be >= 1'
}

if (($SweepBurnInFrom -gt 0 -and $SweepBurnInTo -eq 0) -or ($SweepBurnInTo -gt 0 -and $SweepBurnInFrom -eq 0)) {
  throw 'SweepBurnInFrom and SweepBurnInTo must both be provided when using sweep mode.'
}

if ($SweepBurnInFrom -gt 0 -and $SweepBurnInTo -gt 0 -and $SweepBurnInFrom -gt $SweepBurnInTo) {
  throw 'SweepBurnInFrom must be <= SweepBurnInTo.'
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

# Stable order: generatedAtUtc ascending, then runId, then file.
$orderedEntries = @(
  $entries | Sort-Object `
    @{ Expression = { Get-IsoTimeOrNow -Value $_.generatedAtUtc } ; Ascending = $true }, `
    @{ Expression = { [string]$_.runId } ; Ascending = $true }, `
    @{ Expression = { [string]$_.file } ; Ascending = $true }
)

function Build-ReplayResult {
  param(
    [object[]]$OrderedEntries,
    [int]$SimulatedBurnInRcCount,
    [string]$SourceIndexPath
  )

  $replayedRuns = @()
  for ($i = 0; $i -lt $OrderedEntries.Count; $i++) {
    $entry = $OrderedEntries[$i]
    $runCount = $i + 1
    $inBurnInFreeze = ($runCount -lt $SimulatedBurnInRcCount)

    $replayedRuns += [ordered]@{
      sequence = $runCount
      generatedAtUtc = (Get-IsoTimeOrNow -Value $entry.generatedAtUtc).ToString('o')
      file = [string]$entry.file
      runId = [string]$entry.runId
      runNumber = [string]$entry.runNumber
      gitRef = [string]$entry.gitRef
      gitSha = [string]$entry.gitSha
      releaseCandidateVerdict = [string]$entry.releaseCandidateVerdict
      releaseConfidenceScore = [math]::Round((Get-Numeric -Value $entry.releaseConfidenceScore), 2)
      simulated = [ordered]@{
        runCount = $runCount
        burnInRcCount = $SimulatedBurnInRcCount
        inBurnInFreeze = $inBurnInFreeze
      }
    }
  }

  $firstBurnInExit = $null
  if ($OrderedEntries.Count -ge $SimulatedBurnInRcCount) {
    $firstBurnInExit = $SimulatedBurnInRcCount
  }

  $burnInFlipCount = @($replayedRuns | Where-Object { -not $_.simulated.inBurnInFreeze }).Count
  $identityMonotonic = $true
  if ($replayedRuns.Count -gt 1) {
    for ($idx = 1; $idx -lt $replayedRuns.Count; $idx++) {
      if ($replayedRuns[$idx].sequence -ne ($replayedRuns[$idx - 1].sequence + 1)) {
        $identityMonotonic = $false
        break
      }
    }
  }

  return [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    replayVersion = 'governance_replay_v1'
    schemaVersion = '1.0.0'
    source = [ordered]@{
      indexPath = $SourceIndexPath
      entryCount = $OrderedEntries.Count
    }
    parameters = [ordered]@{
      burnInRcCount = $SimulatedBurnInRcCount
    }
    summary = [ordered]@{
      totalRuns = $replayedRuns.Count
      monotonicSequence = $identityMonotonic
      firstBurnInExitRun = $firstBurnInExit
      burnInExited = ($null -ne $firstBurnInExit)
      runsInBurnIn = @($replayedRuns | Where-Object { $_.simulated.inBurnInFreeze }).Count
      runsPostBurnIn = $burnInFlipCount
    }
    runs = $replayedRuns
  }
}

function Get-ContiguousThresholdRanges {
  param(
    [int[]]$Thresholds
  )

  if ($null -eq $Thresholds -or $Thresholds.Count -eq 0) {
    return @()
  }

  $sorted = @($Thresholds | Sort-Object -Unique)
  $ranges = @()
  $start = $sorted[0]
  $prev = $sorted[0]

  for ($idx = 1; $idx -lt $sorted.Count; $idx++) {
    $current = $sorted[$idx]
    if ($current -ne ($prev + 1)) {
      $ranges += [ordered]@{
        from = $start
        to = $prev
      }
      $start = $current
    }
    $prev = $current
  }

  $ranges += [ordered]@{
    from = $start
    to = $prev
  }

  return $ranges
}

$result = $null
if ($SweepBurnInFrom -gt 0 -and $SweepBurnInTo -gt 0) {
  $sweep = @()
  for ($threshold = $SweepBurnInFrom; $threshold -le $SweepBurnInTo; $threshold++) {
    $sim = Build-ReplayResult -OrderedEntries $orderedEntries -SimulatedBurnInRcCount $threshold -SourceIndexPath $IndexPath
    $sweep += [ordered]@{
      burnInRcCount = $threshold
      firstBurnInExitRun = $sim.summary.firstBurnInExitRun
      burnInExited = $sim.summary.burnInExited
      runsInBurnIn = $sim.summary.runsInBurnIn
      runsPostBurnIn = $sim.summary.runsPostBurnIn
    }
  }

  $exitThresholds = @($sweep | Where-Object { $_.burnInExited } | ForEach-Object { [int]$_.burnInRcCount })
  $frozenThresholds = @($sweep | Where-Object { -not $_.burnInExited } | ForEach-Object { [int]$_.burnInRcCount })
  $firstExitThreshold = if ($exitThresholds.Count -gt 0) { ($exitThresholds | Sort-Object | Select-Object -First 1) } else { $null }
  $lastFrozenThreshold = if ($frozenThresholds.Count -gt 0) { ($frozenThresholds | Sort-Object | Select-Object -Last 1) } else { $null }

  $result = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    replayVersion = 'governance_replay_v1'
    schemaVersion = '1.0.0'
    mode = 'sweep'
    source = [ordered]@{
      indexPath = $IndexPath
      entryCount = $orderedEntries.Count
    }
    parameters = [ordered]@{
      sweepBurnInFrom = $SweepBurnInFrom
      sweepBurnInTo = $SweepBurnInTo
    }
    invariants = [ordered]@{
      scannedThresholdCount = $sweep.Count
      entryCount = $orderedEntries.Count
      thresholdsWhereBurnInExited = $exitThresholds
      thresholdsWhereBurnInStayedFrozen = $frozenThresholds
      exitThresholdRanges = @(Get-ContiguousThresholdRanges -Thresholds $exitThresholds)
      frozenThresholdRanges = @(Get-ContiguousThresholdRanges -Thresholds $frozenThresholds)
      firstExitThreshold = $firstExitThreshold
      lastFrozenThreshold = $lastFrozenThreshold
      transitionBoundary = if ($null -ne $firstExitThreshold -and $null -ne $lastFrozenThreshold) {
        [ordered]@{
          lastFrozenThreshold = $lastFrozenThreshold
          firstExitThreshold = $firstExitThreshold
        }
      } else {
        $null
      }
    }
    sweep = $sweep
  }
} else {
  $result = Build-ReplayResult -OrderedEntries $orderedEntries -SimulatedBurnInRcCount $BurnInRcCount -SourceIndexPath $IndexPath
  $result.mode = 'single'
}

$json = $result | ConvertTo-Json -Depth 20

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outDir = Split-Path -Path $OutputPath -Parent
  if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
    New-Item -Path $outDir -ItemType Directory | Out-Null
  }
  $json | Out-File -FilePath $OutputPath -Encoding utf8
}

# Default output is JSON for deterministic machine parsing.
Write-Output $json
