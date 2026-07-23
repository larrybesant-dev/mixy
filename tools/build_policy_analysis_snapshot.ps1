param(
  [string]$PolicyDriftScorePath = 'tools/reports/policy_drift_score.json',
  [string]$PolicySurfaceDiffPath = 'tools/reports/policy_surface_diff.json',
  [string]$BoundaryDriftPath = 'tools/reports/boundary_drift_analysis.json',
  [string]$HistoryDir = 'tools/reports/history',
  [string]$SnapshotIndexPath = 'tools/reports/history/policy_analysis_snapshot_index.json',
  [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-RequiredJson {
  param([string]$Path, [string]$Label)

  if (-not (Test-Path $Path)) {
    throw "Required artifact not found: $Label @ $Path"
  }

  $raw = Get-Content -Path $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Required artifact is empty: $Label @ $Path"
  }

  return $raw | ConvertFrom-Json
}

$drift = Read-RequiredJson -Path $PolicyDriftScorePath -Label 'PolicyDriftScore'
$surface = Read-RequiredJson -Path $PolicySurfaceDiffPath -Label 'PolicySurfaceDiff'
$boundary = Read-RequiredJson -Path $BoundaryDriftPath -Label 'BoundaryDrift'

if (-not (Test-Path $HistoryDir)) {
  New-Item -Path $HistoryDir -ItemType Directory | Out-Null
}

$refName = if ([string]::IsNullOrWhiteSpace($env:GITHUB_REF_NAME)) { 'local' } else { $env:GITHUB_REF_NAME }
$safeRefName = ($refName -replace '[^A-Za-z0-9._-]', '_')
$runIdentity = if ([string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) {
  [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
} else {
  [string]$env:GITHUB_RUN_ID
}

$snapshotFileName = "policy_analysis_snapshot_${safeRefName}_${runIdentity}.json"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $snapshotPath = Join-Path $HistoryDir $snapshotFileName
  $counter = 1
  while (Test-Path $snapshotPath) {
    $snapshotFileName = "policy_analysis_snapshot_${safeRefName}_${runIdentity}_$counter.json"
    $snapshotPath = Join-Path $HistoryDir $snapshotFileName
    $counter += 1
  }
} else {
  $snapshotPath = $OutputPath
  $snapshotFileName = [IO.Path]::GetFileName($OutputPath)
}

$generatedAtUtc = [DateTime]::UtcNow.ToString('o')
$snapshot = [ordered]@{
  generatedAtUtc = $generatedAtUtc
  snapshotVersion = 'policy_analysis_snapshot_v1'
  schemaVersion = '1.0.0'
  source = [ordered]@{
    runId = $env:GITHUB_RUN_ID
    runNumber = $env:GITHUB_RUN_NUMBER
    gitRef = $env:GITHUB_REF_NAME
    gitSha = $env:GITHUB_SHA
  }
  metrics = [ordered]@{
    driftScore = $drift.summary.driftScore
    tier = $drift.summary.tier
    action = $drift.summary.recommendation.action
    jaccard = $surface.summary.exitSetJaccard
    differingThresholdCount = $surface.summary.differingThresholdCount
    boundaryBehavior = $boundary.summary.boundaryBehavior
    entryCount = $boundary.source.entryCount
    structuralSimilarity = $drift.components.structuralSimilarity.value
    boundaryFragmentation = $drift.components.boundaryFragmentation.normalizedValue
    temporalDrift = $drift.components.temporalDrift.normalizedValue
  }
  artifactPaths = [ordered]@{
    policyDriftScore = $PolicyDriftScorePath
    policySurfaceDiff = $PolicySurfaceDiffPath
    boundaryDrift = $BoundaryDriftPath
  }
}

$snapshotDir = Split-Path -Path $snapshotPath -Parent
if (-not [string]::IsNullOrWhiteSpace($snapshotDir) -and -not (Test-Path $snapshotDir)) {
  New-Item -Path $snapshotDir -ItemType Directory | Out-Null
}

$json = $snapshot | ConvertTo-Json -Depth 20
$json | Out-File -FilePath $snapshotPath -Encoding utf8

$indexDir = Split-Path -Path $SnapshotIndexPath -Parent
if (-not [string]::IsNullOrWhiteSpace($indexDir) -and -not (Test-Path $indexDir)) {
  New-Item -Path $indexDir -ItemType Directory | Out-Null
}

$index = @()
if (Test-Path $SnapshotIndexPath) {
  $rawIndex = Get-Content -Path $SnapshotIndexPath -Raw
  if (-not [string]::IsNullOrWhiteSpace($rawIndex)) {
    $index = @($rawIndex | ConvertFrom-Json)
  }
}

$index += [pscustomobject]@{
  generatedAtUtc = $generatedAtUtc
  file = $snapshotFileName
  runId = $env:GITHUB_RUN_ID
  runNumber = $env:GITHUB_RUN_NUMBER
  gitRef = $env:GITHUB_REF_NAME
  gitSha = $env:GITHUB_SHA
  driftScore = $snapshot.metrics.driftScore
  tier = $snapshot.metrics.tier
  jaccard = $snapshot.metrics.jaccard
  boundaryBehavior = $snapshot.metrics.boundaryBehavior
}

$index | ConvertTo-Json -Depth 20 | Out-File -FilePath $SnapshotIndexPath -Encoding utf8

Write-Host "Policy analysis snapshot written: $snapshotPath"
Write-Host "Policy analysis snapshot index updated: $SnapshotIndexPath"
Write-Output $json
