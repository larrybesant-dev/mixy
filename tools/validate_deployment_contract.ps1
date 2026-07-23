param(
  [string]$ContractPath = 'artifacts/deployment_contract.json',
  [string]$SchemaPath = 'tools/deployment_contract.schema.json',
  [string]$OutputPath = 'artifacts/deployment_contract_validation.json'
)

$ErrorActionPreference = 'Stop'

$allowedReasonCodes = @(
  'app_contract_failure',
  'env_privilege_blocked',
  'service_ownership_blocked',
  'probe_failure',
  'schema_invalid',
  'policy_rejection'
)

function Test-ExactShape {
  param(
    $Object,
    [string[]]$RequiredKeys,
    [string[]]$AllowedKeys
  )

  if ($null -eq $Object) {
    return $false
  }

  $keys = @($Object.PSObject.Properties.Name)
  foreach ($key in $keys) {
    if ($key -notin $AllowedKeys) {
      return $false
    }
  }

  foreach ($requiredKey in $RequiredKeys) {
    if ($requiredKey -notin $keys) {
      return $false
    }
  }

  return $true
}

function Write-ValidationResult {
  param(
    [string]$Status,
    [string]$ReasonCode,
    $Summary
  )

  if ($ReasonCode -notin $allowedReasonCodes) {
    $ReasonCode = 'schema_invalid'
    $Status = 'FAIL'
  }

  $result = [ordered]@{
    status = $Status
    reasonCode = $ReasonCode
    summary = $Summary
  }

  New-Item -ItemType Directory -Path (Split-Path -Path $OutputPath -Parent) -Force | Out-Null
  $result | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath -Encoding utf8
  $result | ConvertTo-Json -Depth 20 | Write-Output

  if ($Status -eq 'FAIL') {
    exit 1
  }

  exit 0
}

if (-not (Test-Path $ContractPath)) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary @{ contractPath = $ContractPath; error = 'missing_contract_file' }
}

if (-not (Test-Path $SchemaPath)) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary @{ schemaPath = $SchemaPath; error = 'missing_schema_file' }
}

$rawContract = ''
$contract = $null

try {
  $rawContract = Get-Content -Path $ContractPath -Raw
  $contract = $rawContract | ConvertFrom-Json
} catch {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary @{ contractPath = $ContractPath; error = 'invalid_json' }
}

if (-not (Test-ExactShape -Object $contract -RequiredKeys @('artifact', 'startup', 'environment', 'privilege', 'networking', 'probeResults', 'governance') -AllowedKeys @('artifact', 'startup', 'environment', 'privilege', 'networking', 'probeResults', 'governance'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if (-not (Test-ExactShape -Object $contract.artifact -RequiredKeys @('commitSha', 'buildId', 'workflowRunId') -AllowedKeys @('commitSha', 'buildId', 'workflowRunId'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if (-not (Test-ExactShape -Object $contract.startup -RequiredKeys @('contractVersion', 'ready', 'checkpoints') -AllowedKeys @('contractVersion', 'ready', 'checkpoints'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if (-not (Test-ExactShape -Object $contract.environment -RequiredKeys @('class', 'os') -AllowedKeys @('class', 'os'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if (-not (Test-ExactShape -Object $contract.privilege -RequiredKeys @('class') -AllowedKeys @('class'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if (-not (Test-ExactShape -Object $contract.networking -RequiredKeys @('port', 'portOwnership') -AllowedKeys @('port', 'portOwnership'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if (-not (Test-ExactShape -Object $contract.probeResults -RequiredKeys @('startupProbe', 'smokeProbe') -AllowedKeys @('startupProbe', 'smokeProbe'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if (-not (Test-ExactShape -Object $contract.governance -RequiredKeys @('decision', 'reasonCode') -AllowedKeys @('decision', 'reasonCode'))) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if ($contract.environment.class -notin @('ci', 'local', 'unknown')) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if ($contract.environment.os -notin @('windows', 'linux', 'macos')) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if ($contract.privilege.class -notin @('admin', 'non-admin', 'restricted')) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if ($contract.networking.portOwnership -notin @('system', 'service', 'user', 'unknown')) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

if ($contract.governance.decision -notin @('allow', 'deny', 'allow-with-degradation')) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

$startupProbe = [string]$contract.probeResults.startupProbe
$smokeProbe = [string]$contract.probeResults.smokeProbe
$startupContractVersion = [string]$contract.startup.contractVersion
$decision = [string]$contract.governance.decision
$reasonCode = [string]$contract.governance.reasonCode
$envClass = [string]$contract.environment.class
$privClass = [string]$contract.privilege.class
$portOwnership = [string]$contract.networking.portOwnership

if ($startupProbe -notin @('pass', 'fail') -or $smokeProbe -notin @('pass', 'fail')) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'probe_failure' -Summary $contract
}

if ([string]::IsNullOrWhiteSpace($startupContractVersion) -or $startupContractVersion -eq 'unknown') {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'app_contract_failure' -Summary $contract
}

$serviceConflict = $portOwnership -in @('service', 'system')
if ($envClass -eq 'ci' -and $privClass -eq 'restricted' -and -not $serviceConflict) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'env_privilege_blocked' -Summary $contract
}

if ($envClass -eq 'unknown' -and $privClass -ne 'admin') {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'env_privilege_blocked' -Summary $contract
}

if ($serviceConflict -and $privClass -ne 'admin' -and $decision -eq 'allow') {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'service_ownership_blocked' -Summary $contract
}

if (($startupProbe -eq 'fail' -or $smokeProbe -eq 'fail') -and $decision -ne 'deny') {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'policy_rejection' -Summary $contract
}

if ($reasonCode -notin $allowedReasonCodes) {
  Write-ValidationResult -Status 'FAIL' -ReasonCode 'schema_invalid' -Summary $contract
}

Write-ValidationResult -Status 'PASS' -ReasonCode $reasonCode -Summary $contract
