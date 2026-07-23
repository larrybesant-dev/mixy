<#
.SYNOPSIS
  Compares burn-in policy surfaces between two verdict histories.

.DESCRIPTION
  Side-effect free diff tool. Reads two verdict index files, computes sweep
  behavior over the same threshold range, and emits a structural comparison.

.PARAMETER IndexPathA
  First verdict index path.

.PARAMETER IndexPathB
  Second verdict index path.

.PARAMETER LabelA
  Display label for first history.

.PARAMETER LabelB
  Display label for second history.

.PARAMETER SweepBurnInFrom
  Inclusive start threshold.

.PARAMETER SweepBurnInTo
  Inclusive end threshold.

.PARAMETER OutputPath
  Optional output path. JSON is always emitted to stdout.
#>
param(
  [string]$IndexPathA = 'tools/reports/history/verdict_index.json',
  [string]$IndexPathB = 'tools/reports/history/verdict_index.json',
  [string]$LabelA = 'history_a',
  [string]$LabelB = 'history_b',
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

function Get-OrderedEntries {
  param([string]$IndexPath)

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

  return @(
    $entries | Sort-Object `
      @{ Expression = { Get-IsoTimeOrNow -Value $_.generatedAtUtc } ; Ascending = $true }, `
      @{ Expression = { [string]$_.runId } ; Ascending = $true }, `
      @{ Expression = { [string]$_.file } ; Ascending = $true }
  )
}

function Build-Surface {
  param(
    [int]$EntryCount,
    [int]$SweepFrom,
    [int]$SweepTo
  )

  $points = @()
  $exitThresholds = @()
  $frozenThresholds = @()

  for ($threshold = $SweepFrom; $threshold -le $SweepTo; $threshold++) {
    $burnInExited = ($EntryCount -ge $threshold)
    if ($burnInExited) {
      $exitThresholds += $threshold
    } else {
      $frozenThresholds += $threshold
    }

    $points += [ordered]@{
      burnInRcCount = $threshold
      burnInExited = $burnInExited
    }
  }

  $firstExitThreshold = if ($exitThresholds.Count -gt 0) { ($exitThresholds | Select-Object -First 1) } else { $null }
  $lastFrozenThreshold = if ($frozenThresholds.Count -gt 0) { ($frozenThresholds | Select-Object -Last 1) } else { $null }

  return [ordered]@{
    entryCount = $EntryCount
    firstExitThreshold = $firstExitThreshold
    lastFrozenThreshold = $lastFrozenThreshold
    thresholdsWhereBurnInExited = $exitThresholds
    thresholdsWhereBurnInStayedFrozen = $frozenThresholds
    points = $points
  }
}

if ($SweepBurnInFrom -lt 1) {
  throw 'SweepBurnInFrom must be >= 1'
}
if ($SweepBurnInTo -lt $SweepBurnInFrom) {
  throw 'SweepBurnInTo must be >= SweepBurnInFrom'
}

$entriesA = Get-OrderedEntries -IndexPath $IndexPathA
$entriesB = Get-OrderedEntries -IndexPath $IndexPathB

$surfaceA = Build-Surface -EntryCount $entriesA.Count -SweepFrom $SweepBurnInFrom -SweepTo $SweepBurnInTo
$surfaceB = Build-Surface -EntryCount $entriesB.Count -SweepFrom $SweepBurnInFrom -SweepTo $SweepBurnInTo

$exitSetA = @($surfaceA.thresholdsWhereBurnInExited | ForEach-Object { [string]$_ })
$exitSetB = @($surfaceB.thresholdsWhereBurnInExited | ForEach-Object { [string]$_ })
$union = @($exitSetA + $exitSetB | Sort-Object -Unique)
$intersection = @($union | Where-Object { ($exitSetA -contains $_) -and ($exitSetB -contains $_) })
$jaccard = if ($union.Count -eq 0) { 1.0 } else { [math]::Round(($intersection.Count / [double]$union.Count), 4) }

$pointDiffs = @()
$mapB = @{}
foreach ($pt in @($surfaceB.points)) {
  $mapB[[string]$pt.burnInRcCount] = [bool]$pt.burnInExited
}
foreach ($pt in @($surfaceA.points)) {
  $k = [string]$pt.burnInRcCount
  $bVal = if ($mapB.ContainsKey($k)) { [bool]$mapB[$k] } else { $null }
  if ($null -ne $bVal -and [bool]$pt.burnInExited -ne $bVal) {
    $pointDiffs += [int]$pt.burnInRcCount
  }
}

$result = [ordered]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  diffVersion = 'policy_surface_diff_v1'
  schemaVersion = '1.0.0'
  source = [ordered]@{
    historyA = [ordered]@{ label = $LabelA; indexPath = $IndexPathA; entryCount = $entriesA.Count }
    historyB = [ordered]@{ label = $LabelB; indexPath = $IndexPathB; entryCount = $entriesB.Count }
  }
  parameters = [ordered]@{
    sweepBurnInFrom = $SweepBurnInFrom
    sweepBurnInTo = $SweepBurnInTo
  }
  summary = [ordered]@{
    entryCountDelta = ($entriesA.Count - $entriesB.Count)
    firstExitThresholdDelta = if ($null -ne $surfaceA.firstExitThreshold -and $null -ne $surfaceB.firstExitThreshold) { ($surfaceA.firstExitThreshold - $surfaceB.firstExitThreshold) } else { $null }
    lastFrozenThresholdDelta = if ($null -ne $surfaceA.lastFrozenThreshold -and $null -ne $surfaceB.lastFrozenThreshold) { ($surfaceA.lastFrozenThreshold - $surfaceB.lastFrozenThreshold) } else { $null }
    exitSetJaccard = $jaccard
    differingThresholds = $pointDiffs
    differingThresholdCount = $pointDiffs.Count
  }
  surfaces = [ordered]@{
    historyA = $surfaceA
    historyB = $surfaceB
  }
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
