param(
  [string]$ContractPath = 'tools/policy_analysis_contract.schema.json',
  [string]$ReplayPath = 'tools/reports/replay_timeline.json',
  [string]$BoundaryDriftPath = 'tools/reports/boundary_drift_analysis.json',
  [string]$PolicySurfaceDiffPath = '',
  [string]$PolicyDriftScorePath = '',
  [string]$PolicyAnalysisDeltaPath = '',
  [string]$ValidationMode = 'observe',
  [string]$OutputValidationStatusPath = 'tools/reports/policy_analysis_contract_validation_status.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ContractFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Required analysis artifact not found: $Path"
  }
}

function Test-RequiredFields {
  param(
    [object]$Object,
    [string[]]$Fields,
    [string]$ArtifactName
  )

  foreach ($field in $Fields) {
    if (-not ($Object.PSObject.Properties.Name -contains $field)) {
      throw "Contract violation in ${ArtifactName}: missing required field '$field'."
    }
  }
}

function Test-ArrayField {
  param(
    [object]$Value,
    [string]$ArtifactName,
    [string]$FieldName
  )

  if ($null -eq $Value) {
    throw "Contract violation in ${ArtifactName}: field '$FieldName' is null, expected array."
  }

  if (-not ($Value -is [System.Array])) {
    throw "Contract violation in ${ArtifactName}: field '$FieldName' must be an array."
  }
}

function Test-ObjectField {
  param(
    [object]$Value,
    [string]$ArtifactName,
    [string]$FieldName
  )

  if ($null -eq $Value) {
    throw "Contract violation in ${ArtifactName}: field '$FieldName' is null, expected object."
  }

  if ($Value -is [System.Array] -or (($Value -isnot [pscustomobject]) -and ($Value -isnot [hashtable]))) {
    throw "Contract violation in ${ArtifactName}: field '$FieldName' must be an object."
  }
}

try {
  Test-ContractFile -Path $ContractPath
  Test-ContractFile -Path $ReplayPath
  Test-ContractFile -Path $BoundaryDriftPath

  $contract = Get-Content -Raw -Path $ContractPath | ConvertFrom-Json
  $expectedSchemaVersion = [string]$contract.schemaVersion
  if ([string]::IsNullOrWhiteSpace($expectedSchemaVersion)) {
    throw 'Contract violation: missing schemaVersion in analysis contract.'
  }

  $replay = Get-Content -Raw -Path $ReplayPath | ConvertFrom-Json
  $boundary = Get-Content -Raw -Path $BoundaryDriftPath | ConvertFrom-Json

  if ([string]$replay.mode -eq 'single') {
    $replayContract = $contract.analysisArtifacts.replaySingle
    Test-RequiredFields -Object $replay -Fields @($replayContract.requiredTopLevel) -ArtifactName 'replay_single'
    Test-ObjectField -Value $replay.source -ArtifactName 'replay_single' -FieldName 'source'
    Test-ObjectField -Value $replay.parameters -ArtifactName 'replay_single' -FieldName 'parameters'
    Test-ObjectField -Value $replay.summary -ArtifactName 'replay_single' -FieldName 'summary'
    Test-ArrayField -Value $replay.runs -ArtifactName 'replay_single' -FieldName 'runs'
    Test-RequiredFields -Object $replay.source -Fields @($replayContract.requiredSourceFields) -ArtifactName 'replay_single.source'
    Test-RequiredFields -Object $replay.parameters -Fields @($replayContract.requiredParameterFields) -ArtifactName 'replay_single.parameters'
    Test-RequiredFields -Object $replay.summary -Fields @($replayContract.requiredSummaryFields) -ArtifactName 'replay_single.summary'
    foreach ($run in @($replay.runs)) {
      Test-RequiredFields -Object $run -Fields @($replayContract.requiredRunFields) -ArtifactName 'replay_single.runs[]'
      Test-ObjectField -Value $run.simulated -ArtifactName 'replay_single.runs[]' -FieldName 'simulated'
      Test-RequiredFields -Object $run.simulated -Fields @($replayContract.requiredSimulatedFields) -ArtifactName 'replay_single.runs[].simulated'
    }
  }
  elseif ([string]$replay.mode -eq 'sweep') {
    $replayContract = $contract.analysisArtifacts.replaySweep
    Test-RequiredFields -Object $replay -Fields @($replayContract.requiredTopLevel) -ArtifactName 'replay_sweep'
    Test-ObjectField -Value $replay.source -ArtifactName 'replay_sweep' -FieldName 'source'
    Test-ObjectField -Value $replay.parameters -ArtifactName 'replay_sweep' -FieldName 'parameters'
    Test-ObjectField -Value $replay.invariants -ArtifactName 'replay_sweep' -FieldName 'invariants'
    Test-ArrayField -Value $replay.sweep -ArtifactName 'replay_sweep' -FieldName 'sweep'
    Test-RequiredFields -Object $replay.source -Fields @($replayContract.requiredSourceFields) -ArtifactName 'replay_sweep.source'
    Test-RequiredFields -Object $replay.parameters -Fields @($replayContract.requiredParameterFields) -ArtifactName 'replay_sweep.parameters'
    Test-RequiredFields -Object $replay.invariants -Fields @($replayContract.requiredInvariantFields) -ArtifactName 'replay_sweep.invariants'
    Test-ArrayField -Value $replay.invariants.thresholdsWhereBurnInExited -ArtifactName 'replay_sweep.invariants' -FieldName 'thresholdsWhereBurnInExited'
    Test-ArrayField -Value $replay.invariants.thresholdsWhereBurnInStayedFrozen -ArtifactName 'replay_sweep.invariants' -FieldName 'thresholdsWhereBurnInStayedFrozen'
    Test-ArrayField -Value $replay.invariants.exitThresholdRanges -ArtifactName 'replay_sweep.invariants' -FieldName 'exitThresholdRanges'
    Test-ArrayField -Value $replay.invariants.frozenThresholdRanges -ArtifactName 'replay_sweep.invariants' -FieldName 'frozenThresholdRanges'
    foreach ($range in @($replay.invariants.exitThresholdRanges)) {
      Test-RequiredFields -Object $range -Fields @($replayContract.requiredRangeFields) -ArtifactName 'replay_sweep.invariants.exitThresholdRanges[]'
    }
    foreach ($range in @($replay.invariants.frozenThresholdRanges)) {
      Test-RequiredFields -Object $range -Fields @($replayContract.requiredRangeFields) -ArtifactName 'replay_sweep.invariants.frozenThresholdRanges[]'
    }
    foreach ($item in @($replay.sweep)) {
      Test-RequiredFields -Object $item -Fields @($replayContract.requiredSweepFields) -ArtifactName 'replay_sweep.sweep[]'
    }
  }
  else {
    throw "Contract violation in replay artifact: unsupported mode '$($replay.mode)'."
  }

  if ([string]$replay.schemaVersion -ne $expectedSchemaVersion) {
    throw "Contract violation in replay artifact: schemaVersion mismatch (expected $expectedSchemaVersion)."
  }

  $boundaryContract = $contract.analysisArtifacts.boundaryDrift
  Test-RequiredFields -Object $boundary -Fields @($boundaryContract.requiredTopLevel) -ArtifactName 'boundary_drift'
  Test-ObjectField -Value $boundary.source -ArtifactName 'boundary_drift' -FieldName 'source'
  Test-ObjectField -Value $boundary.parameters -ArtifactName 'boundary_drift' -FieldName 'parameters'
  Test-ObjectField -Value $boundary.summary -ArtifactName 'boundary_drift' -FieldName 'summary'
  Test-ArrayField -Value $boundary.prefixes -ArtifactName 'boundary_drift' -FieldName 'prefixes'
  Test-RequiredFields -Object $boundary.source -Fields @($boundaryContract.requiredSourceFields) -ArtifactName 'boundary_drift.source'
  Test-RequiredFields -Object $boundary.parameters -Fields @($boundaryContract.requiredParameterFields) -ArtifactName 'boundary_drift.parameters'
  Test-RequiredFields -Object $boundary.summary -Fields @($boundaryContract.requiredSummaryFields) -ArtifactName 'boundary_drift.summary'
  Test-ArrayField -Value $boundary.summary.distinctFirstExitThresholds -ArtifactName 'boundary_drift.summary' -FieldName 'distinctFirstExitThresholds'
  Test-ArrayField -Value $boundary.summary.distinctLastFrozenThresholds -ArtifactName 'boundary_drift.summary' -FieldName 'distinctLastFrozenThresholds'
  if (@($boundaryContract.allowedBoundaryBehavior) -notcontains [string]$boundary.summary.boundaryBehavior) {
    throw "Contract violation in boundary_drift.summary: invalid boundaryBehavior '$($boundary.summary.boundaryBehavior)'."
  }
  foreach ($prefix in @($boundary.prefixes)) {
    Test-RequiredFields -Object $prefix -Fields @($boundaryContract.requiredPrefixFields) -ArtifactName 'boundary_drift.prefixes[]'
  }

  if ([string]$boundary.schemaVersion -ne $expectedSchemaVersion) {
    throw "Contract violation in boundary drift artifact: schemaVersion mismatch (expected $expectedSchemaVersion)."
  }

  if (-not [string]::IsNullOrWhiteSpace($PolicySurfaceDiffPath)) {
    Test-ContractFile -Path $PolicySurfaceDiffPath
    $surfaceDiff = Get-Content -Raw -Path $PolicySurfaceDiffPath | ConvertFrom-Json
    $diffContract = $contract.analysisArtifacts.policySurfaceDiff

    Test-RequiredFields -Object $surfaceDiff -Fields @($diffContract.requiredTopLevel) -ArtifactName 'policy_surface_diff'
    Test-ObjectField -Value $surfaceDiff.source -ArtifactName 'policy_surface_diff' -FieldName 'source'
    Test-ObjectField -Value $surfaceDiff.parameters -ArtifactName 'policy_surface_diff' -FieldName 'parameters'
    Test-ObjectField -Value $surfaceDiff.summary -ArtifactName 'policy_surface_diff' -FieldName 'summary'
    Test-ObjectField -Value $surfaceDiff.surfaces -ArtifactName 'policy_surface_diff' -FieldName 'surfaces'

    Test-RequiredFields -Object $surfaceDiff.source -Fields @($diffContract.requiredSourceTopLevel) -ArtifactName 'policy_surface_diff.source'
    Test-ObjectField -Value $surfaceDiff.source.historyA -ArtifactName 'policy_surface_diff.source' -FieldName 'historyA'
    Test-ObjectField -Value $surfaceDiff.source.historyB -ArtifactName 'policy_surface_diff.source' -FieldName 'historyB'
    Test-RequiredFields -Object $surfaceDiff.source.historyA -Fields @($diffContract.requiredSourceHistoryFields) -ArtifactName 'policy_surface_diff.source.historyA'
    Test-RequiredFields -Object $surfaceDiff.source.historyB -Fields @($diffContract.requiredSourceHistoryFields) -ArtifactName 'policy_surface_diff.source.historyB'

    Test-RequiredFields -Object $surfaceDiff.parameters -Fields @($diffContract.requiredParameterFields) -ArtifactName 'policy_surface_diff.parameters'
    Test-RequiredFields -Object $surfaceDiff.summary -Fields @($diffContract.requiredSummaryFields) -ArtifactName 'policy_surface_diff.summary'
    Test-ArrayField -Value $surfaceDiff.summary.differingThresholds -ArtifactName 'policy_surface_diff.summary' -FieldName 'differingThresholds'

    Test-RequiredFields -Object $surfaceDiff.surfaces -Fields @($diffContract.requiredSurfacesTopLevel) -ArtifactName 'policy_surface_diff.surfaces'
    foreach ($surfaceName in @('historyA', 'historyB')) {
      $surface = $surfaceDiff.surfaces.$surfaceName
      Test-ObjectField -Value $surface -ArtifactName 'policy_surface_diff.surfaces' -FieldName $surfaceName
      Test-RequiredFields -Object $surface -Fields @($diffContract.requiredSurfaceFields) -ArtifactName "policy_surface_diff.surfaces.$surfaceName"
      Test-ArrayField -Value $surface.thresholdsWhereBurnInExited -ArtifactName "policy_surface_diff.surfaces.$surfaceName" -FieldName 'thresholdsWhereBurnInExited'
      Test-ArrayField -Value $surface.thresholdsWhereBurnInStayedFrozen -ArtifactName "policy_surface_diff.surfaces.$surfaceName" -FieldName 'thresholdsWhereBurnInStayedFrozen'
      Test-ArrayField -Value $surface.points -ArtifactName "policy_surface_diff.surfaces.$surfaceName" -FieldName 'points'
      foreach ($point in @($surface.points)) {
        Test-RequiredFields -Object $point -Fields @($diffContract.requiredPointFields) -ArtifactName "policy_surface_diff.surfaces.$surfaceName.points[]"
      }
    }

    if ([string]$surfaceDiff.schemaVersion -ne $expectedSchemaVersion) {
      throw "Contract violation in policy surface diff artifact: schemaVersion mismatch (expected $expectedSchemaVersion)."
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($PolicyDriftScorePath)) {
    Test-ContractFile -Path $PolicyDriftScorePath
    $driftScore = Get-Content -Raw -Path $PolicyDriftScorePath | ConvertFrom-Json
    $scoreContract = $contract.analysisArtifacts.policyDriftScore

    Test-RequiredFields -Object $driftScore -Fields @($scoreContract.requiredTopLevel) -ArtifactName 'policy_drift_score'
    Test-ObjectField -Value $driftScore.source -ArtifactName 'policy_drift_score' -FieldName 'source'
    Test-ObjectField -Value $driftScore.parameters -ArtifactName 'policy_drift_score' -FieldName 'parameters'
    Test-ObjectField -Value $driftScore.components -ArtifactName 'policy_drift_score' -FieldName 'components'
    Test-ObjectField -Value $driftScore.summary -ArtifactName 'policy_drift_score' -FieldName 'summary'
    Test-ObjectField -Value $driftScore.breakdown -ArtifactName 'policy_drift_score' -FieldName 'breakdown'

    Test-RequiredFields -Object $driftScore.source -Fields @($scoreContract.requiredSourceFields) -ArtifactName 'policy_drift_score.source'
    Test-RequiredFields -Object $driftScore.parameters -Fields @($scoreContract.requiredParameterFields) -ArtifactName 'policy_drift_score.parameters'
    Test-RequiredFields -Object $driftScore.summary -Fields @($scoreContract.requiredSummaryFields) -ArtifactName 'policy_drift_score.summary'

    Test-ObjectField -Value $driftScore.components.structuralSimilarity -ArtifactName 'policy_drift_score.components' -FieldName 'structuralSimilarity'
    Test-ObjectField -Value $driftScore.components.boundaryFragmentation -ArtifactName 'policy_drift_score.components' -FieldName 'boundaryFragmentation'
    Test-ObjectField -Value $driftScore.components.temporalDrift -ArtifactName 'policy_drift_score.components' -FieldName 'temporalDrift'

    Test-RequiredFields -Object $driftScore.components.structuralSimilarity -Fields @($scoreContract.requiredStructuralSimilarityFields) -ArtifactName 'policy_drift_score.components.structuralSimilarity'
    Test-RequiredFields -Object $driftScore.components.boundaryFragmentation -Fields @($scoreContract.requiredBoundaryFragmentationFields) -ArtifactName 'policy_drift_score.components.boundaryFragmentation'
    Test-RequiredFields -Object $driftScore.components.temporalDrift -Fields @($scoreContract.requiredTemporalDriftFields) -ArtifactName 'policy_drift_score.components.temporalDrift'

    if (@($scoreContract.allowedTiers) -notcontains [string]$driftScore.summary.tier) {
      throw "Contract violation in policy_drift_score.summary: invalid tier '$($driftScore.summary.tier)'."
    }

    Test-ObjectField -Value $driftScore.summary.recommendation -ArtifactName 'policy_drift_score.summary' -FieldName 'recommendation'
    Test-RequiredFields -Object $driftScore.summary.recommendation -Fields @($scoreContract.requiredRecommendationFields) -ArtifactName 'policy_drift_score.summary.recommendation'

    if (@($scoreContract.allowedActions) -notcontains [string]$driftScore.summary.recommendation.action) {
      throw "Contract violation in policy_drift_score.summary.recommendation: invalid action '$($driftScore.summary.recommendation.action)'."
    }

    Test-RequiredFields -Object $driftScore.breakdown -Fields @($scoreContract.requiredBreakdownFields) -ArtifactName 'policy_drift_score.breakdown'
    Test-ObjectField -Value $driftScore.breakdown.componentContribution -ArtifactName 'policy_drift_score.breakdown' -FieldName 'componentContribution'
    Test-RequiredFields -Object $driftScore.breakdown.componentContribution -Fields @($scoreContract.requiredComponentContributionFields) -ArtifactName 'policy_drift_score.breakdown.componentContribution'

    if ([string]$driftScore.schemaVersion -ne $expectedSchemaVersion) {
      throw "Contract violation in policy drift score artifact: schemaVersion mismatch (expected $expectedSchemaVersion)."
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($PolicyAnalysisDeltaPath)) {
    Test-ContractFile -Path $PolicyAnalysisDeltaPath
    $delta = Get-Content -Raw -Path $PolicyAnalysisDeltaPath | ConvertFrom-Json
    $deltaContract = $contract.analysisArtifacts.policyAnalysisDelta

    Test-RequiredFields -Object $delta -Fields @($deltaContract.requiredTopLevel) -ArtifactName 'policy_analysis_delta'
    Test-ObjectField -Value $delta.source -ArtifactName 'policy_analysis_delta' -FieldName 'source'
    Test-ObjectField -Value $delta.current -ArtifactName 'policy_analysis_delta' -FieldName 'current'
    Test-ObjectField -Value $delta.summary -ArtifactName 'policy_analysis_delta' -FieldName 'summary'

    Test-RequiredFields -Object $delta.source -Fields @($deltaContract.requiredSourceFields) -ArtifactName 'policy_analysis_delta.source'
    Test-RequiredFields -Object $delta.current -Fields @($deltaContract.requiredCurrentFields) -ArtifactName 'policy_analysis_delta.current'
    Test-RequiredFields -Object $delta.summary -Fields @($deltaContract.requiredSummaryFields) -ArtifactName 'policy_analysis_delta.summary'

    if ($null -ne $delta.previous) {
      Test-ObjectField -Value $delta.previous -ArtifactName 'policy_analysis_delta' -FieldName 'previous'
      Test-RequiredFields -Object $delta.previous -Fields @($deltaContract.requiredPreviousFields) -ArtifactName 'policy_analysis_delta.previous'
    }

    if (@($deltaContract.allowedModes) -notcontains [string]$delta.summary.mode) {
      throw "Contract violation in policy_analysis_delta.summary: invalid mode '$($delta.summary.mode)'."
    }

    if (@($deltaContract.allowedChangeClassification) -notcontains [string]$delta.summary.classification) {
      throw "Contract violation in policy_analysis_delta.summary: invalid classification '$($delta.summary.classification)'."
    }

    if ([string]$delta.summary.changeClassification -ne [string]$delta.summary.classification) {
      throw "Contract violation in policy_analysis_delta.summary: changeClassification must match classification."
    }

    if (@($deltaContract.allowedConfidence) -notcontains [string]$delta.summary.confidence) {
      throw "Contract violation in policy_analysis_delta.summary: invalid confidence '$($delta.summary.confidence)'."
    }

    if ([string]$delta.schemaVersion -ne $expectedSchemaVersion) {
      throw "Contract violation in policy analysis delta artifact: schemaVersion mismatch (expected $expectedSchemaVersion)."
    }
  }

  $status = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    schemaVersion = $expectedSchemaVersion
    status = 'passed'
    validationMode = $ValidationMode
  }
  $status | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputValidationStatusPath -Encoding utf8
  Write-Host 'Policy analysis contract validation passed.'
}
catch {
  $status = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    schemaVersion = 'unknown'
    status = 'failed'
    validationMode = $ValidationMode
    error = $_.Exception.MessageModel
  }
  $status | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputValidationStatusPath -Encoding utf8

  if ($ValidationMode -eq 'enforce') {
    throw
  }

  Write-Warning "Policy analysis contract validation failed in observe mode: $($_.Exception.MessageModel)"
}
