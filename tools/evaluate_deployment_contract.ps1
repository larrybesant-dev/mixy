param(
  [string]$ContractPath = 'artifacts/deployment_contract.json',
  [string]$SchemaPath = 'tools/deployment_contract.schema.json',
  [string]$OutputPath = 'artifacts/deployment_contract_evaluation.json',
  [string]$ResolvedContractPath = 'artifacts/deployment_contract.resolved.json',
  [string]$CurrentHashPath = 'artifacts/hash_chain/current_contract_hash.txt',
  [string]$DevEnvironmentContractPath = 'artifacts/dev_environment_contract.json',
  [string]$LocalDevContractHashPath = 'artifacts/dev_environment_contract.hash.local.txt',
  [string]$CiDevContractHashPath = 'artifacts/dev_environment_contract.hash.ci.txt'
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

$stateSequence = @('INIT', 'COLLECTED', 'VALIDATED', 'GOVERNED', 'BOOTSTRAP', 'FINAL')

$requiredStartupCheckpoints = @('firstFrameRendered')
$isCiRuntime = ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true')

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )

  New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force | Out-Null
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Convert-ToCanonicalData {
  param($Value)

  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $ordered = [ordered]@{}
    foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
      $ordered[$key] = Convert-ToCanonicalData -Value $Value[$key]
    }
    return $ordered
  }

  if ($Value -is [System.Management.Automation.PSCustomObject]) {
    $ordered = [ordered]@{}
    $keys = @($Value.PSObject.Properties.Name | Sort-Object)
    foreach ($key in $keys) {
      $ordered[$key] = Convert-ToCanonicalData -Value $Value.$key
    }
    return $ordered
  }

  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $items = @()
    foreach ($item in $Value) {
      $items += ,(Convert-ToCanonicalData -Value $item)
    }
    return $items
  }

  return $Value
}

function Convert-ToCanonicalJson {
  param($Value)

  $canonical = Convert-ToCanonicalData -Value $Value
  return ($canonical | ConvertTo-Json -Depth 50 -Compress)
}

function Get-Sha256Hex {
  param([string]$InputText)

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
  $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
}

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

function Write-Evaluation {
  param(
    [string]$Status,
    [string]$ReasonCode,
    $FinalContract,
    [array]$Observations = @()
  )

  if ($ReasonCode -notin $allowedReasonCodes) {
    $ReasonCode = 'schema_invalid'
    $Status = 'FAIL'
    $FinalContract.governance.reasonCode = $ReasonCode
    $FinalContract.governance.decision = 'deny'
  }

  $resolvedJson = $FinalContract | ConvertTo-Json -Depth 30
  Write-Utf8NoBom -Path $ResolvedContractPath -Content $resolvedJson

  Write-Utf8NoBom -Path $CurrentHashPath -Content $FinalContract.contractHash

  $result = [ordered]@{
    status = $Status
    reasonCode = $ReasonCode
    summary = $FinalContract
    observations = @($Observations)
  }

  $resultJson = $result | ConvertTo-Json -Depth 30
  Write-Utf8NoBom -Path $OutputPath -Content $resultJson
  $result | ConvertTo-Json -Depth 30 | Write-Output

  if ($Status -eq 'FAIL') {
    exit 1
  }

  exit 0
}

function Get-CanonicalHash {
  param($Contract)

  $json = Convert-ToCanonicalJson -Value $Contract
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
}

function Set-Deny {
  param(
    $Contract,
    [string]$ReasonCode
  )

  $Contract.governance.decision = 'deny'
  $Contract.governance.reasonCode = $ReasonCode
}

function Is-PlaceholderValue {
  param($Value)

  if ($null -eq $Value) {
    return $true
  }

  if ($Value -is [string]) {
    $v = $Value.Trim().ToLowerInvariant()
    return $v -in @('', 'unknown', 'missing', 'invalid', 'pending')
  }

  return $false
}

function Is-ValidHash {
  param([string]$Value)

  return (-not [string]::IsNullOrWhiteSpace($Value)) -and $Value -match '^[a-f0-9]{64}$'
}

function Read-HashValue {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
    return $null
  }

  try {
    $value = (Get-Content -Path $Path -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
      return $null
    }
    return $value
  }
  catch {
    return $null
  }
}

function Get-DevEnvironmentContractContext {
  param([string]$Path)

  # Non-authority boundary:
  # Any field originating from dev_environment_contract is informational only and MUST NOT
  # influence governance decision outcomes.
  $context = [ordered]@{
    status = 'missing'
    hash = $null
    summaryFlags = $null
  }

  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
    return $context
  }

  try {
    $raw = Get-Content -Path $Path -Raw
    $parsed = $raw | ConvertFrom-Json

    if (-not (Test-ExactShape -Object $parsed -RequiredKeys @('contractType', 'contractVersion', 'generatedAtRunId', 'contentHash', 'summaryFlags', 'environment', 'editor', 'encoding', 'extensions') -AllowedKeys @('contractType', 'contractVersion', 'generatedAtRunId', 'contentHash', 'summaryFlags', 'environment', 'editor', 'encoding', 'extensions'))) {
      $context.status = 'invalid'
      return $context
    }

    if ($parsed.contractType -ne 'dev_environment') {
      $context.status = 'invalid'
      return $context
    }

    if (-not (Test-ExactShape -Object $parsed.summaryFlags -RequiredKeys @('settingsPresent', 'settingsHashPresent', 'utf8NoBomPreferred', 'detectIndentationDisabled', 'powershellExtensionInstalled', 'dartExtensionInstalled', 'flutterExtensionInstalled') -AllowedKeys @('settingsPresent', 'settingsHashPresent', 'utf8NoBomPreferred', 'detectIndentationDisabled', 'powershellExtensionInstalled', 'dartExtensionInstalled', 'flutterExtensionInstalled'))) {
      $context.status = 'invalid'
      return $context
    }

    $context.status = 'present'
    $context.hash = 'sha256:' + (Get-Sha256Hex -InputText (Convert-ToCanonicalJson -Value $parsed))
    $context.summaryFlags = Convert-ToCanonicalData -Value $parsed.summaryFlags
    return $context
  }
  catch {
    $context.status = 'invalid'
    return $context
  }
}

function Write-FinalEvaluation {
  param(
    $FinalContract,
    [string]$Decision,
    [string]$ReasonCode,
    [array]$Observations = @()
  )

  $FinalContract.contractState = 'GOVERNED'
  $FinalContract.governance.decision = $Decision
  $FinalContract.governance.reasonCode = $ReasonCode
  $FinalContract.contractState = 'FINAL'

  # Evaluator self-verifies canonical determinism before committing hash.
  $canonicalOne = Convert-ToCanonicalJson -Value $FinalContract
  $canonicalTwo = Convert-ToCanonicalJson -Value $FinalContract
  if ($canonicalOne -ne $canonicalTwo) {
    $FinalContract.governance.decision = 'deny'
    $FinalContract.governance.reasonCode = 'policy_rejection'
    $FinalContract.contractHash = 'nondeterministic'
    Write-Evaluation -Status 'FAIL' -ReasonCode 'policy_rejection' -FinalContract $FinalContract -Observations $Observations
  }

  $hashOne = Get-Sha256Hex -InputText $canonicalOne
  $hashTwo = Get-Sha256Hex -InputText $canonicalTwo
  if ($hashOne -ne $hashTwo) {
    $FinalContract.governance.decision = 'deny'
    $FinalContract.governance.reasonCode = 'policy_rejection'
    $FinalContract.contractHash = 'nondeterministic'
    Write-Evaluation -Status 'FAIL' -ReasonCode 'policy_rejection' -FinalContract $FinalContract -Observations $Observations
  }

  $FinalContract.contractHash = $hashOne
  $status = if ($FinalContract.governance.decision -eq 'allow') { 'PASS' } else { 'FAIL' }
  Write-Evaluation -Status $status -ReasonCode $FinalContract.governance.reasonCode -FinalContract $FinalContract -Observations $Observations
}

$observations = @()
$localDevContractHash = Read-HashValue -Path $LocalDevContractHashPath
$ciDevContractHash = Read-HashValue -Path $CiDevContractHashPath
if (-not [string]::IsNullOrWhiteSpace($env:MIXVY_LOCAL_DEV_CONTRACT_HASH)) {
  $localDevContractHash = [string]$env:MIXVY_LOCAL_DEV_CONTRACT_HASH
}
if (-not [string]::IsNullOrWhiteSpace($env:MIXVY_CI_DEV_CONTRACT_HASH)) {
  $ciDevContractHash = [string]$env:MIXVY_CI_DEV_CONTRACT_HASH
}

if (-not [string]::IsNullOrWhiteSpace($localDevContractHash) -and -not [string]::IsNullOrWhiteSpace($ciDevContractHash) -and $localDevContractHash -ne $ciDevContractHash) {
  $observations += [ordered]@{
    severity = 'warning'
    reasonCode = 'environment_drift_detected'
    localDevContractHash = $localDevContractHash
    ciDevContractHash = $ciDevContractHash
  }
}

if (-not (Test-Path $ContractPath)) {
  $fallback = [ordered]@{
    authority = [ordered]@{ runtime = 'flutter'; ci = 'github-actions'; resolvedBy = 'deployment_contract' }
    contractState = 'FINAL'
    contractHash = 'invalid'
    previousContractHash = $null
    artifact = [ordered]@{ commitSha = 'unknown'; buildId = 'unknown'; workflowRunId = 'unknown' }
    startup = [ordered]@{ contractVersion = 'unknown'; ready = $false; checkpoints = @() }
    environment = [ordered]@{ class = 'local'; os = 'windows' }
    privilege = [ordered]@{ class = 'restricted' }
    networking = [ordered]@{ port = 8080; portOwnership = 'user' }
    probeResults = [ordered]@{ startupProbe = 'fail'; smokeProbe = 'fail' }
    governance = [ordered]@{ decision = 'deny'; reasonCode = 'schema_invalid' }
  }
  Write-Evaluation -Status 'FAIL' -ReasonCode 'schema_invalid' -FinalContract $fallback
}

$rawContract = ''
$contract = $null

try {
  $rawContract = Get-Content -Path $ContractPath -Raw
  $contract = $rawContract | ConvertFrom-Json
} catch {
  $fallback = [ordered]@{
    authority = [ordered]@{ runtime = 'flutter'; ci = 'github-actions'; resolvedBy = 'deployment_contract' }
    contractState = 'FINAL'
    contractHash = 'invalid'
    previousContractHash = $null
    artifact = [ordered]@{ commitSha = 'unknown'; buildId = 'unknown'; workflowRunId = 'unknown' }
    startup = [ordered]@{ contractVersion = 'unknown'; ready = $false; checkpoints = @() }
    environment = [ordered]@{ class = 'unknown'; os = 'windows' }
    privilege = [ordered]@{ class = 'restricted' }
    networking = [ordered]@{ port = 8080; portOwnership = 'unknown' }
    probeResults = [ordered]@{ startupProbe = 'fail'; smokeProbe = 'fail' }
    governance = [ordered]@{ decision = 'deny'; reasonCode = 'schema_invalid' }
  }
  Write-Evaluation -Status 'FAIL' -ReasonCode 'schema_invalid' -FinalContract $fallback
}

$schemaOk = $true

if ($schemaOk) {
  if (-not (Test-ExactShape -Object $contract -RequiredKeys @('authority', 'contractState', 'contractHash', 'previousContractHash', 'artifact', 'startup', 'environment', 'privilege', 'networking', 'probeResults', 'governance') -AllowedKeys @('authority', 'contractState', 'contractHash', 'previousContractHash', 'artifact', 'startup', 'environment', 'privilege', 'networking', 'probeResults', 'governance'))) {
    $schemaOk = $false
  }
}

if ($schemaOk) {
  if (-not (Test-ExactShape -Object $contract.authority -RequiredKeys @('runtime', 'ci', 'resolvedBy') -AllowedKeys @('runtime', 'ci', 'resolvedBy'))) { $schemaOk = $false }
  if (-not (Test-ExactShape -Object $contract.artifact -RequiredKeys @('commitSha', 'buildId', 'workflowRunId') -AllowedKeys @('commitSha', 'buildId', 'workflowRunId'))) { $schemaOk = $false }
  if (-not (Test-ExactShape -Object $contract.startup -RequiredKeys @('contractVersion', 'ready', 'checkpoints') -AllowedKeys @('contractVersion', 'ready', 'checkpoints'))) { $schemaOk = $false }
  if (-not (Test-ExactShape -Object $contract.environment -RequiredKeys @('class', 'os') -AllowedKeys @('class', 'os'))) { $schemaOk = $false }
  if (-not (Test-ExactShape -Object $contract.privilege -RequiredKeys @('class') -AllowedKeys @('class'))) { $schemaOk = $false }
  if (-not (Test-ExactShape -Object $contract.networking -RequiredKeys @('port', 'portOwnership') -AllowedKeys @('port', 'portOwnership'))) { $schemaOk = $false }
  if (-not (Test-ExactShape -Object $contract.probeResults -RequiredKeys @('startupProbe', 'smokeProbe') -AllowedKeys @('startupProbe', 'smokeProbe'))) { $schemaOk = $false }
  if (-not (Test-ExactShape -Object $contract.governance -RequiredKeys @('decision', 'reasonCode') -AllowedKeys @('decision', 'reasonCode'))) { $schemaOk = $false }
}

if ($schemaOk) {
  if ($contract.authority.runtime -ne 'flutter' -or $contract.authority.ci -ne 'github-actions' -or $contract.authority.resolvedBy -ne 'deployment_contract') { $schemaOk = $false }
  if ($contract.contractState -notin $stateSequence) { $schemaOk = $false }
  if ($contract.environment.class -notin @('ci', 'local')) { $schemaOk = $false }
  if ($contract.environment.os -notin @('windows', 'linux', 'macos')) { $schemaOk = $false }
  if ($contract.privilege.class -notin @('admin', 'non-admin', 'restricted')) { $schemaOk = $false }
  if ($contract.networking.portOwnership -notin @('system', 'service', 'user')) { $schemaOk = $false }
  if ($contract.probeResults.startupProbe -notin @('pass', 'fail')) { $schemaOk = $false }
  if ($contract.probeResults.smokeProbe -notin @('pass', 'fail')) { $schemaOk = $false }
  if ($contract.governance.decision -notin @('allow', 'deny', 'allow-with-degradation')) { $schemaOk = $false }
  if ($contract.governance.reasonCode -notin $allowedReasonCodes) { $schemaOk = $false }
}

$final = [ordered]@{
  authority = [ordered]@{ runtime = 'flutter'; ci = 'github-actions'; resolvedBy = 'deployment_contract' }
  contractState = 'INIT'
  contractHash = 'unknown'
  previousContractHash = $contract.previousContractHash
  artifact = [ordered]@{ commitSha = [string]$contract.artifact.commitSha; buildId = [string]$contract.artifact.buildId; workflowRunId = [string]$contract.artifact.workflowRunId }
  startup = [ordered]@{ contractVersion = [string]$contract.startup.contractVersion; ready = [bool]$contract.startup.ready; checkpoints = @($contract.startup.checkpoints | ForEach-Object { [string]$_ } | Sort-Object -Unique) }
  environment = [ordered]@{ class = [string]$contract.environment.class; os = [string]$contract.environment.os; contract = Get-DevEnvironmentContractContext -Path $DevEnvironmentContractPath }
  privilege = [ordered]@{ class = [string]$contract.privilege.class }
  networking = [ordered]@{ port = [int]$contract.networking.port; portOwnership = [string]$contract.networking.portOwnership }
  probeResults = [ordered]@{ startupProbe = [string]$contract.probeResults.startupProbe; smokeProbe = [string]$contract.probeResults.smokeProbe }
  governance = [ordered]@{ decision = 'deny'; reasonCode = 'schema_invalid' }
}

if (-not $schemaOk) {
  Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations
}

# State transition: INIT -> COLLECTED -> VALIDATED
if ($contract.contractState -ne 'INIT') {
  Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations
}

$final.contractState = 'COLLECTED'
$final.contractState = 'VALIDATED'

# Completeness and placeholder checks for required production fields.
if (Is-PlaceholderValue -Value $final.startup.contractVersion) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }
if (Is-PlaceholderValue -Value $final.environment.class) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }
if (Is-PlaceholderValue -Value $final.environment.os) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }
if (Is-PlaceholderValue -Value $final.privilege.class) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }
if (Is-PlaceholderValue -Value $final.networking.portOwnership) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }
if (Is-PlaceholderValue -Value $final.probeResults.startupProbe) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }
if (Is-PlaceholderValue -Value $final.probeResults.smokeProbe) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }

# Semantic validation for startup readiness contract completeness.
if (-not $final.startup.ready) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'app_contract_failure' -Observations $observations }
if ($final.startup.checkpoints.Count -eq 0) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'app_contract_failure' -Observations $observations }
foreach ($requiredCheckpoint in $requiredStartupCheckpoints) {
  if ($requiredCheckpoint -notin $final.startup.checkpoints) {
    Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'app_contract_failure' -Observations $observations
  }
}

# Input existence and environment-policy alignment.
if ($isCiRuntime -and $final.environment.class -ne 'ci') { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'env_privilege_blocked' -Observations $observations }
if (-not $isCiRuntime -and $final.environment.class -eq 'ci') { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'env_privilege_blocked' -Observations $observations }
if ($final.environment.class -eq 'ci' -and $final.privilege.class -notin @('admin', 'restricted')) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'env_privilege_blocked' -Observations $observations }
if ($final.environment.class -eq 'local' -and $final.privilege.class -notin @('admin', 'non-admin')) { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'env_privilege_blocked' -Observations $observations }
if ($final.environment.class -eq 'ci' -and $final.networking.portOwnership -eq 'unknown') { Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'schema_invalid' -Observations $observations }

if ($final.environment.class -eq 'ci' -and $null -eq $final.previousContractHash) {
  $final.contractState = 'BOOTSTRAP'
  Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'policy_rejection' -Observations $observations
}

if ($null -ne $final.previousContractHash -and -not (Is-ValidHash -Value ([string]$final.previousContractHash))) {
  Write-FinalEvaluation -FinalContract $final -Decision 'deny' -ReasonCode 'policy_rejection' -Observations $observations
}

$reasonCode = 'policy_rejection'
$decision = 'allow'

if ($decision -eq 'allow' -and ($final.probeResults.startupProbe -ne 'pass' -or $final.probeResults.smokeProbe -ne 'pass')) {
  $decision = 'deny'
  $reasonCode = 'probe_failure'
}

$serviceConflict = $final.networking.portOwnership -in @('service', 'system')
if ($decision -eq 'allow' -and $final.environment.class -eq 'ci' -and $final.privilege.class -eq 'restricted' -and -not $serviceConflict) {
  $decision = 'deny'
  $reasonCode = 'env_privilege_blocked'
}

if ($decision -eq 'allow' -and $serviceConflict -and $final.privilege.class -ne 'admin') {
  $decision = 'allow-with-degradation'
  $reasonCode = 'service_ownership_blocked'
}

if ($decision -eq 'allow-with-degradation' -and ($final.probeResults.startupProbe -ne 'pass' -or $final.probeResults.smokeProbe -ne 'pass')) {
  $decision = 'deny'
  $reasonCode = 'probe_failure'
}

Write-FinalEvaluation -FinalContract $final -Decision $decision -ReasonCode $reasonCode -Observations $observations
