param(
  [string]$ProposalPath = 'tools/reports/proposed_thresholds.json',
  [string]$ActivePolicyPath = 'tools/release_governor_policy.json',
  [string]$SafetyFloorsPath = 'tools/release_governor_safety_floors.json',
  [string]$ReceiptPath = 'tools/reports/policy_promotion_receipt.json',
  [string]$HistoryIndexPath = 'tools/reports/policy_history_index.json',
  [string]$ContractVersion = '1.0.0',
  [string]$Approver = '',
  [string]$ChangeTicket = '',
  [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ProposalPath)) {
  throw "Proposal file not found: $ProposalPath"
}
if (-not (Test-Path $ActivePolicyPath)) {
  throw "Active policy not found: $ActivePolicyPath"
}
if (-not (Test-Path $SafetyFloorsPath)) {
  throw "Safety floors not found: $SafetyFloorsPath"
}

$proposal = Get-Content -Raw -Path $ProposalPath | ConvertFrom-Json
$active = Get-Content -Raw -Path $ActivePolicyPath | ConvertFrom-Json
$floors = Get-Content -Raw -Path $SafetyFloorsPath | ConvertFrom-Json

if ($null -ne $active.contract -and -not [string]::IsNullOrWhiteSpace([string]$active.contract.contract_version)) {
  $ContractVersion = [string]$active.contract.contract_version
}

$newConfidence = [double]$proposal.recommendedThresholds.confidenceThreshold
$floorConfidence = [double]$floors.minConfidenceThreshold
if ($newConfidence -lt $floorConfidence) {
  throw "Proposed confidence threshold ($newConfidence) is below safety floor ($floorConfidence)."
}

$policyDeltaSummary = [ordered]@{
  confidenceThreshold = [ordered]@{
    current = [double]$active.confidenceThreshold
    proposed = [double]$proposal.recommendedThresholds.confidenceThreshold
    delta = [math]::Round(([double]$proposal.recommendedThresholds.confidenceThreshold - [double]$active.confidenceThreshold), 2)
  }
  slopeBlockThreshold = [ordered]@{
    current = [double]$active.slopeBlockThreshold
    proposed = [double]$proposal.recommendedThresholds.slopeBlockThreshold
    delta = [math]::Round(([double]$proposal.recommendedThresholds.slopeBlockThreshold - [double]$active.slopeBlockThreshold), 2)
  }
  varianceIncreaseWarningPercent = [ordered]@{
    current = [double]$active.varianceIncreaseWarningPercent
    proposed = [double]$proposal.recommendedThresholds.varianceIncreaseWarningPercent
    delta = [math]::Round(([double]$proposal.recommendedThresholds.varianceIncreaseWarningPercent - [double]$active.varianceIncreaseWarningPercent), 2)
  }
}

$receiptDir = Split-Path -Path $ReceiptPath -Parent
if (-not (Test-Path $receiptDir)) {
  New-Item -Path $receiptDir -ItemType Directory | Out-Null
}

$previewReceipt = [ordered]@{
  contract_version = $ContractVersion
  artifact_mode = 'primary'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  receiptVersion = 'policy_promotion_receipt_v1'
  status = if ($Apply) { 'pending_apply_validation' } else { 'preview_only' }
  proposalPath = $ProposalPath
  activePolicyPath = $ActivePolicyPath
  policy_delta_summary = $policyDeltaSummary
  applyRequested = [bool]$Apply
}

if (-not $Apply) {
  $previewReceipt | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReceiptPath -Encoding utf8
  Write-Host "Policy preview receipt written: $ReceiptPath"
  Write-Host 'Manual approval protection: re-run with -Apply -Approver <name> -ChangeTicket <id> to promote thresholds.'
  exit 0
}

if ([string]::IsNullOrWhiteSpace($Approver)) {
  throw 'Approver is required when -Apply is set.'
}
if ([string]::IsNullOrWhiteSpace($ChangeTicket)) {
  throw 'ChangeTicket is required when -Apply is set.'
}

$active.confidenceThreshold = $newConfidence
$active.slopeBlockThreshold = [double]$proposal.recommendedThresholds.slopeBlockThreshold
$active.varianceIncreaseWarningPercent = [double]$proposal.recommendedThresholds.varianceIncreaseWarningPercent

$active | Add-Member -NotePropertyName lastPolicyPromotion -NotePropertyValue ([ordered]@{
  promotedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  approver = $Approver
  changeTicket = $ChangeTicket
  sourceProposal = $ProposalPath
}) -Force

$active | ConvertTo-Json -Depth 10 | Out-File -FilePath $ActivePolicyPath -Encoding utf8

$appliedReceipt = [ordered]@{
  contract_version = $ContractVersion
  artifact_mode = 'primary'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  receiptVersion = 'policy_promotion_receipt_v1'
  status = 'applied'
  proposalPath = $ProposalPath
  activePolicyPath = $ActivePolicyPath
  approver = $Approver
  changeTicket = $ChangeTicket
  policy_delta_summary = $policyDeltaSummary
}

$appliedReceipt | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReceiptPath -Encoding utf8

$historyIndex = if (Test-Path $HistoryIndexPath) {
  Get-Content -Raw -Path $HistoryIndexPath | ConvertFrom-Json
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
  eventType = 'promotion'
  policyVersion = $active.modelVersion
  changeTicket = $ChangeTicket
  approver = $Approver
  changeMagnitude = [math]::Round(
    [math]::Abs([double]$policyDeltaSummary.confidenceThreshold.delta) +
    ([math]::Abs([double]$policyDeltaSummary.slopeBlockThreshold.delta) * 10) +
    ([math]::Abs([double]$policyDeltaSummary.varianceIncreaseWarningPercent.delta) / 2),
    4
  )
  policyDeltaSummary = $policyDeltaSummary
}
$historyIndex.entries = $entries
$historyIndex | ConvertTo-Json -Depth 20 | Out-File -FilePath $HistoryIndexPath -Encoding utf8

Write-Host "Policy history index updated: $HistoryIndexPath"
Write-Host "Policy promotion receipt written: $ReceiptPath"
Write-Host "Policy promoted successfully by $Approver (ticket: $ChangeTicket)."