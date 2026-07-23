param(
  [string]$PolicyDriftScorePath = 'tools/reports/policy_drift_score.json',
  [string]$PolicySurfaceDiffPath = 'tools/reports/policy_surface_diff.json',
  [string]$BoundaryDriftPath = 'tools/reports/boundary_drift_analysis.json',
  [string]$PolicyAnalysisDeltaPath = 'tools/reports/policy_analysis_delta.json',
  [string]$ValidationStatusPath = 'tools/reports/policy_analysis_contract_validation_status.json',
  [string]$SummaryPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-OptionalJson {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
    return $null
  }

  $raw = Get-Content -Path $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return $null
  }

  return $raw | ConvertFrom-Json
}

$summaryTarget = if ([string]::IsNullOrWhiteSpace($SummaryPath)) { $env:GITHUB_STEP_SUMMARY } else { $SummaryPath }
if ([string]::IsNullOrWhiteSpace($summaryTarget)) {
  Write-Host 'No summary target provided. Skipping policy analysis summary emission.'
  exit 0
}

$driftScore = Read-OptionalJson -Path $PolicyDriftScorePath
$surfaceDiff = Read-OptionalJson -Path $PolicySurfaceDiffPath
$boundaryDrift = Read-OptionalJson -Path $BoundaryDriftPath
$deltaArtifact = Read-OptionalJson -Path $PolicyAnalysisDeltaPath
$validationStatus = Read-OptionalJson -Path $ValidationStatusPath

$scoreValue = if ($null -ne $driftScore) { $driftScore.summary.driftScore } else { 'unavailable' }
$tierValue = if ($null -ne $driftScore) { $driftScore.summary.tier } else { 'unavailable' }
$actionValue = if ($null -ne $driftScore) { $driftScore.summary.recommendation.action } else { 'unavailable' }
$jaccardValue = if ($null -ne $surfaceDiff) { $surfaceDiff.summary.exitSetJaccard } else { 'unavailable' }
$thresholdDiffCount = if ($null -ne $surfaceDiff) { $surfaceDiff.summary.differingThresholdCount } else { 'unavailable' }
$boundaryBehaviorRaw = if ($null -ne $boundaryDrift) { [string]$boundaryDrift.summary.boundaryBehavior } else { 'unavailable' }
$boundaryBehavior = if ($boundaryBehaviorRaw -eq 'insufficient_history') { 'insufficient_history (low confidence)' } else { $boundaryBehaviorRaw }
$validationValue = if ($null -ne $validationStatus) { $validationStatus.status } else { 'unavailable' }
$hardFailReason = if ($null -ne $driftScore) { $driftScore.summary.hardFailReason } else { $null }
$softFailReason = if ($null -ne $driftScore) { $driftScore.summary.softFailReason } else { $null }

$lines = @(
  '## Policy Analysis Summary',
  '',
  '| Signal | Value |',
  '|---|---|',
  "| DriftScore | $scoreValue / 100 |",
  "| Tier | $tierValue |",
  "| Action | $actionValue |",
  "| Exit Set Jaccard | $jaccardValue |",
  "| Differing Threshold Count | $thresholdDiffCount |",
  "| Boundary Behavior | $boundaryBehavior |",
  "| Analysis Contract | $validationValue |",
  ''
)

if (-not [string]::IsNullOrWhiteSpace([string]$hardFailReason)) {
  $lines += "Hard fail reason: $hardFailReason"
  $lines += ''
}

if (-not [string]::IsNullOrWhiteSpace([string]$softFailReason)) {
  $lines += "Soft fail reason: $softFailReason"
  $lines += ''
}

if ($null -ne $driftScore) {
  $lines += 'Component breakdown:'
  $lines += ''
  $lines += "- S (structural similarity): $($driftScore.components.structuralSimilarity.value)"
  $lines += "- T (boundary fragmentation): $($driftScore.components.boundaryFragmentation.normalizedValue)"
  $lines += "- E (temporal drift): $($driftScore.components.temporalDrift.normalizedValue)"
  $lines += ''
}

if ($null -ne $deltaArtifact) {
  $lines += 'Change vs Previous Run:'
  $lines += ''

  $classificationValue = if ($deltaArtifact.summary.PSObject.Properties.Name -contains 'classification') {
    $deltaArtifact.summary.classification
  } else {
    $deltaArtifact.summary.changeClassification
  }

  if ([string]$deltaArtifact.summary.mode -eq 'baseline') {
    $lines += '- Baseline run: no previous snapshot available.'
    $lines += "- Classification: $classificationValue"
    $lines += "- Confidence: $($deltaArtifact.summary.confidence)"
    $lines += ''
  } else {
    $prevScore = $deltaArtifact.previous.driftScore
    $currScore = $deltaArtifact.current.driftScore
    $prevJaccard = $deltaArtifact.previous.jaccard
    $currJaccard = $deltaArtifact.current.jaccard
    $prevBoundary = $deltaArtifact.previous.boundaryBehavior
    $currBoundary = $deltaArtifact.current.boundaryBehavior
    $deltaScore = $deltaArtifact.summary.driftScoreDelta
    $deltaJaccard = $deltaArtifact.summary.jaccardDelta

    $scoreSign = if ($deltaScore -gt 0) { '+' } else { '' }
    $jaccardSign = if ($deltaJaccard -gt 0) { '+' } else { '' }

    $lines += "- DriftScore: $prevScore -> $currScore ($scoreSign$deltaScore)"
    $lines += "- Jaccard: $prevJaccard -> $currJaccard ($jaccardSign$deltaJaccard)"
    $lines += "- Boundary Behavior: $prevBoundary -> $currBoundary"
    $lines += "- Classification: $classificationValue"
    $lines += "- Confidence: $($deltaArtifact.summary.confidence)"
    $lines += ''
  }
}

$lines -join "`n" | Out-File -FilePath $summaryTarget -Encoding utf8 -Append
Write-Host "Policy analysis summary written to: $summaryTarget"
