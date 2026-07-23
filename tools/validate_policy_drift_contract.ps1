param(
  [string]$ContractPath = 'tools/policy_drift_contract.schema.json',
  [string]$ProposedPath = 'tools/reports/proposed_thresholds.json',
  [string]$SnapshotPath = 'tools/reports/rc_policy_snapshot_v1.json',
  [string]$ApprovalRequestPath = 'tools/reports/policy_approval_request.json',
  [string]$StatusPath = 'tools/reports/policy_tuner_status.json',
  [string]$ValidationMode = 'observe',
  [string]$OutputValidationStatusPath = 'tools/reports/policy_contract_validation_status.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Required contract artifact not found: $Path"
  }
}

function Ensure-Fields {
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

try {
  Ensure-File -Path $ContractPath
  Ensure-File -Path $ProposedPath
  Ensure-File -Path $SnapshotPath
  Ensure-File -Path $ApprovalRequestPath
  Ensure-File -Path $StatusPath

  $contract = Get-Content -Raw -Path $ContractPath | ConvertFrom-Json
  $expectedContractVersion = [string]$contract.properties.contract_version.const
  if ([string]::IsNullOrWhiteSpace($expectedContractVersion)) {
    throw 'Contract violation: missing properties.contract_version.const.'
  }

  $states = @($contract.properties.allowedRecommendationStates.items.enum)
  if ($states.Count -eq 0) {
    throw 'Contract violation: allowedRecommendationStates is empty.'
  }

  $artifactContract = $contract.examples[0].artifacts

  $proposed = Get-Content -Raw -Path $ProposedPath | ConvertFrom-Json
  $snapshot = Get-Content -Raw -Path $SnapshotPath | ConvertFrom-Json
  $approval = Get-Content -Raw -Path $ApprovalRequestPath | ConvertFrom-Json
  $status = Get-Content -Raw -Path $StatusPath | ConvertFrom-Json

  Ensure-Fields -Object $proposed -Fields @($artifactContract.proposedThresholds.requiredFields) -ArtifactName 'proposed_thresholds'
  Ensure-Fields -Object $snapshot -Fields @($artifactContract.snapshot.requiredFields) -ArtifactName 'rc_policy_snapshot_v1'
  Ensure-Fields -Object $approval -Fields @($artifactContract.approvalRequest.requiredFields) -ArtifactName 'policy_approval_request'
  Ensure-Fields -Object $status -Fields @($artifactContract.status.requiredFields) -ArtifactName 'policy_tuner_status'

  if ($proposed.contract_version -ne $expectedContractVersion -or $snapshot.contract_version -ne $expectedContractVersion -or $approval.contract_version -ne $expectedContractVersion -or $status.contract_version -ne $expectedContractVersion) {
    throw "Contract violation: artifact contract_version mismatch (expected $expectedContractVersion)."
  }

  if ($states -notcontains [string]$proposed.recommendationState) {
    throw "Contract violation in proposed_thresholds: invalid recommendationState '$($proposed.recommendationState)'."
  }
  if ($states -notcontains [string]$approval.recommendationState) {
    throw "Contract violation in policy_approval_request: invalid recommendationState '$($approval.recommendationState)'."
  }
  if ($states -notcontains [string]$status.recommendationState) {
    throw "Contract violation in policy_tuner_status: invalid recommendationState '$($status.recommendationState)'."
  }

  $validationStatus = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    contract_version = $expectedContractVersion
    status = 'passed'
    validationMode = $ValidationMode
  }
  $validationStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputValidationStatusPath -Encoding utf8
  Write-Host 'Policy drift contract validation passed.'
}
catch {
  $errorMessageModel = $_.Exception.MessageModel
  $validationStatus = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    contract_version = 'unknown'
    status = 'failed'
    validationMode = $ValidationMode
    error = $errorMessageModel
  }
  $validationStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputValidationStatusPath -Encoding utf8

  if ($ValidationMode -eq 'enforce') {
    throw
  }

  Write-Warning "Policy drift contract validation failed in observe mode: $errorMessageModel"
}