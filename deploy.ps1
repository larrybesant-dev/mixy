param(
  [int]$Port = 9090,
  [string]$BuildPath = 'build/web',
  [string]$DeployRoot = 'deploy'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$startupLogPath = 'tools/reports/startup_timeline.log'
$startupReportPath = 'tools/reports/startup_probe_report.json'
$smokeReportPath = 'tools/reports/web_failure_smoke_report.json'
$preflightContractPath = 'artifacts/preflight_contract.json'
$contractPath = 'artifacts/deployment_contract.json'
$evaluationPath = 'artifacts/deployment_contract_evaluation.json'
$resolvedContractPath = 'artifacts/deployment_contract.resolved.json'
$previousHashPath = 'artifacts/hash_chain/previous_contract_hash.txt'
$currentHashPath = 'artifacts/hash_chain/current_contract_hash.txt'
$devEnvironmentContractPath = 'artifacts/dev_environment_contract.json'
$localDevEnvironmentHashPath = 'artifacts/dev_environment_contract.hash.local.txt'
$ciDevEnvironmentHashPath = 'artifacts/dev_environment_contract.hash.ci.txt'
$appUrl = "http://127.0.0.1:$Port/"
$global:StageResults = @()

function Write-Stage {
  param([string]$Name)
  Write-Host ""
  Write-Host "== $Name =="
}

function Invoke-PowerShellScript {
  param(
    [string]$ScriptPath,
    [string[]]$Arguments = @(),
    [switch]$AllowFailure
  )

  $stdoutPath = Join-Path $env:TEMP ("mixvy-" + [guid]::NewGuid().ToString() + "-stdout.log")
  $stderrPath = Join-Path $env:TEMP ("mixvy-" + [guid]::NewGuid().ToString() + "-stderr.log")
  $argumentList = @('-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments

  try {
    $proc = Start-Process -FilePath 'powershell' -ArgumentList $argumentList -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

    if (Test-Path $stdoutPath) {
      Get-Content -Path $stdoutPath | ForEach-Object { Write-Host $_ }
    }
    if (Test-Path $stderrPath) {
      Get-Content -Path $stderrPath | ForEach-Object { Write-Host $_ }
    }

    if (-not $AllowFailure -and $proc.ExitCode -ne 0) {
      throw "Script failed: $ScriptPath (exit=$($proc.ExitCode))"
    }

    return $proc.ExitCode
  }
  finally {
    Remove-Item -Path $stdoutPath -ErrorAction SilentlyContinue
    Remove-Item -Path $stderrPath -ErrorAction SilentlyContinue
  }
}

function Invoke-CommandWithExitCode {
  param(
    [scriptblock]$Command,
    [string]$Name
  )

  try {
    & $Command | Out-Null
    return $LASTEXITCODE
  }
  catch {
    Write-Host "[stage-fail] ${Name}: $($_.Exception.Message)"
    return 1
  }
}

function Wait-AppReady {
  param(
    [string]$Url,
    [int]$TimeoutSeconds = 45
  )

  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    try {
      Invoke-WebRequest -Uri $Url -UseBasicParsing | Out-Null
      return
    }
    catch {
      Start-Sleep -Seconds 1
    }
  }

  throw "App did not become ready at $Url within $TimeoutSeconds seconds."
}

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )

  New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force | Out-Null
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Add-StageResult {
  param(
    [string]$Stage,
    [string]$Status,
    [string]$ReasonCode,
    [int]$ExitCode
  )

  $global:StageResults += [ordered]@{
    stage = $Stage
    status = $Status
    reasonCode = $ReasonCode
    exitCode = $ExitCode
  }
}

function Write-ReleaseTelemetryFooter {
  param(
    $Evaluation
  )

  # Projection-only invariant: this footer must summarize evaluator output as-is and must never add authority logic.
  $decision = if ($null -ne $Evaluation.summary -and $null -ne $Evaluation.summary.governance -and -not [string]::IsNullOrWhiteSpace([string]$Evaluation.summary.governance.decision)) { [string]$Evaluation.summary.governance.decision } else { 'unknown' }
  $contractHash = if ($null -ne $Evaluation.summary -and -not [string]::IsNullOrWhiteSpace([string]$Evaluation.summary.contractHash)) { [string]$Evaluation.summary.contractHash } else { 'unknown' }
  $previousHash = if ($null -ne $Evaluation.summary -and -not [string]::IsNullOrWhiteSpace([string]$Evaluation.summary.previousContractHash)) { [string]$Evaluation.summary.previousContractHash } else { 'unknown' }
  $devContractHash = if ($null -ne $Evaluation.summary -and $null -ne $Evaluation.summary.environment -and $null -ne $Evaluation.summary.environment.contract -and -not [string]::IsNullOrWhiteSpace([string]$Evaluation.summary.environment.contract.hash)) { [string]$Evaluation.summary.environment.contract.hash } else { 'unknown' }
  $evaluationState = if ($null -ne $Evaluation.summary -and -not [string]::IsNullOrWhiteSpace([string]$Evaluation.summary.contractState)) { [string]$Evaluation.summary.contractState } else { 'unknown' }

  $observationCount = 0
  $driftDetected = $false
  if ($null -ne $Evaluation.observations) {
    $observationCount = @($Evaluation.observations).Count
    foreach ($obs in @($Evaluation.observations)) {
      if ($null -ne $obs -and [string]$obs.reasonCode -eq 'environment_drift_detected') {
        $driftDetected = $true
        break
      }
    }
  }

  Write-Host '=== MIXVY RELEASE SUMMARY ==='
  Write-Host "decision: $decision"
  Write-Host "contractHash: $contractHash"
  Write-Host "previousHash: $previousHash"
  Write-Host "devContractHash: $devContractHash"
  Write-Host "driftDetected: $driftDetected"
  Write-Host "observationCount: $observationCount"
  Write-Host "evaluationState: $evaluationState"
  Write-Host '============================='
}

function Persist-AuditHistory {
  param(
    [string]$Root,
    [string]$ContractFile,
    [string]$ResolvedFile,
    [string]$EvaluationFile,
    [string]$DevEnvironmentContractFile,
    $ResolvedContract
  )

  $historyStamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  $historyDir = Join-Path $Root "history/$historyStamp"
  New-Item -ItemType Directory -Path $historyDir -Force | Out-Null

  if (-not (Test-Path $ContractFile)) { throw "Missing audit input: $ContractFile" }
  if (-not (Test-Path $ResolvedFile)) { throw "Missing audit input: $ResolvedFile" }
  if (-not (Test-Path $EvaluationFile)) { throw "Missing audit input: $EvaluationFile" }

  Copy-Item -Path $ContractFile -Destination (Join-Path $historyDir 'deployment_contract.json') -Force
  Copy-Item -Path $ResolvedFile -Destination (Join-Path $historyDir 'deployment_contract.resolved.json') -Force
  Copy-Item -Path $EvaluationFile -Destination (Join-Path $historyDir 'evaluation.json') -Force
  if (-not [string]::IsNullOrWhiteSpace($DevEnvironmentContractFile) -and (Test-Path $DevEnvironmentContractFile)) {
    Copy-Item -Path $DevEnvironmentContractFile -Destination (Join-Path $historyDir 'dev_environment_contract.json') -Force
  }
  if (Test-Path $localDevEnvironmentHashPath) {
    Copy-Item -Path $localDevEnvironmentHashPath -Destination (Join-Path $historyDir 'dev_environment_contract.hash.local.txt') -Force
  }
  if (Test-Path $ciDevEnvironmentHashPath) {
    Copy-Item -Path $ciDevEnvironmentHashPath -Destination (Join-Path $historyDir 'dev_environment_contract.hash.ci.txt') -Force
  }
  Write-Utf8NoBom -Path (Join-Path $historyDir 'hash.txt') -Content "contractHash=$($ResolvedContract.contractHash)`npreviousHash=$($ResolvedContract.previousContractHash)"
}

try {
  New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
  New-Item -ItemType Directory -Path 'artifacts/hash_chain' -Force | Out-Null
  New-Item -ItemType Directory -Path 'tools/reports' -Force | Out-Null

  $resetExitCode = 0
  $preflightExitCode = 0
  $buildExitCode = 0
  $startupProbeExitCode = 0
  $smokeProbeExitCode = 0
  $devEnvironmentContractExitCode = 0
  $contractBuildExitCode = 0
  $evaluateExitCode = 0

  Write-Stage 'Reset environment'
  $resetExitCode = Invoke-PowerShellScript -ScriptPath 'tools/reset_dev_environment.ps1' -AllowFailure
  if ($resetExitCode -ne 0) {
    Write-Host "[stage-fail] reset_dev_environment exit=$resetExitCode"
    Add-StageResult -Stage 'reset_dev_environment' -Status 'failed' -ReasonCode 'env_privilege_blocked' -ExitCode $resetExitCode
  } else {
    Add-StageResult -Stage 'reset_dev_environment' -Status 'success' -ReasonCode 'none' -ExitCode $resetExitCode
  }

  Write-Stage 'Port preflight'
  $mode = if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') { 'Force' } else { 'Safe' }
  $preflightExitCode = Invoke-PowerShellScript -ScriptPath 'tools/port_preflight_guard.ps1' -Arguments @(
    '-Port', "$Port",
    '-Mode', $mode,
    '-ExecutionEnvironment', 'auto',
    '-TimeoutSeconds', '45',
    '-StabilizationSeconds', '3',
    '-OutputPath', $preflightContractPath
  ) -AllowFailure
  if ($preflightExitCode -ne 0 -or -not (Test-Path $preflightContractPath)) {
    Write-Host "[stage-fail] port_preflight_guard execution failure exit=$preflightExitCode"
    Add-StageResult -Stage 'port_preflight' -Status 'failed' -ReasonCode 'probe_failure' -ExitCode $preflightExitCode
  } else {
    try {
      $preflightContract = Get-Content -Path $preflightContractPath -Raw | ConvertFrom-Json
      $preflightStatus = [string]$preflightContract.status
      $preflightReason = [string]$preflightContract.reasonCode
      if ([string]::IsNullOrWhiteSpace($preflightReason)) {
        $preflightReason = 'none'
      }

      if ($preflightStatus -eq 'pass') {
        Add-StageResult -Stage 'port_preflight' -Status 'success' -ReasonCode 'none' -ExitCode 0
      } else {
        Add-StageResult -Stage 'port_preflight' -Status 'failed' -ReasonCode $preflightReason -ExitCode 0
      }
    }
    catch {
      Write-Host '[stage-fail] preflight contract parse failed'
      Add-StageResult -Stage 'port_preflight' -Status 'failed' -ReasonCode 'schema_invalid' -ExitCode 0
    }
  }

  Write-Stage 'Validate Firestore data integrity'
  $firestoreValidateExitCode = Invoke-CommandWithExitCode -Name 'validate-firestore-truth' -Command {
    & node functions/scripts/validate-firestore-truth.js
  }
  if ($firestoreValidateExitCode -ne 0) {
    Write-Host "[stage-fail] Firestore truth validation failed (exit=$firestoreValidateExitCode)"
    Write-Host "             Run: cd functions && npm run repair:all:apply"
    Add-StageResult -Stage 'validate_firestore_truth' -Status 'failed' -ReasonCode 'data_violations' -ExitCode $firestoreValidateExitCode
  } else {
    Add-StageResult -Stage 'validate_firestore_truth' -Status 'success' -ReasonCode 'none' -ExitCode 0
  }

  Write-Stage 'Build Flutter web'
  $buildExitCode = Invoke-CommandWithExitCode -Name 'flutter build web --release' -Command {
    & flutter build web --release
  }
  if ($buildExitCode -ne 0) {
    Write-Host "[stage-fail] flutter build web --release exit=$buildExitCode"
    Add-StageResult -Stage 'build_flutter_web' -Status 'failed' -ReasonCode 'probe_failure' -ExitCode $buildExitCode
  } else {
    Add-StageResult -Stage 'build_flutter_web' -Status 'success' -ReasonCode 'none' -ExitCode $buildExitCode
  }

  Write-Stage 'Run startup probe'
  $startupProbeExitCode = Invoke-PowerShellScript -ScriptPath 'tools/run_startup_probe.ps1' -Arguments @(
    '-Mode', 'startup',
    '-SkipPreflight',
    '-Port', "$Port",
    '-BuildPath', $BuildPath,
    '-AppUrl', $appUrl,
    '-StartupLogPath', $startupLogPath,
    '-StartupReportPath', $startupReportPath,
    '-WebSmokeReportPath', $smokeReportPath
  ) -AllowFailure
  if ($startupProbeExitCode -ne 0) {
    Write-Host "[stage-fail] startup probe exit=$startupProbeExitCode"
    Add-StageResult -Stage 'startup_probe' -Status 'failed' -ReasonCode 'probe_failure' -ExitCode $startupProbeExitCode
  } else {
    Add-StageResult -Stage 'startup_probe' -Status 'success' -ReasonCode 'none' -ExitCode $startupProbeExitCode
  }

  if (-not (Test-Path $startupReportPath)) {
    $startupFallback = [ordered]@{
      contractVersion = 'startup_probe_report_v1'
      status = 'FAIL'
      reason = 'probe_failure'
      finalContract = [ordered]@{
        contractVersion = 'unknown'
        ready = $false
        checkpoints = [ordered]@{}
      }
    }
    Write-Utf8NoBom -Path $startupReportPath -Content ($startupFallback | ConvertTo-Json -Depth 10)
  }

  Write-Stage 'Run smoke probe'
  $server = $null
  try {
    $server = Start-Process npx -ArgumentList @('http-server', $BuildPath, '-p', "$Port", '-a', '127.0.0.1', '-s') -PassThru
    Wait-AppReady -Url $appUrl -TimeoutSeconds 45

    $env:STARTUP_APP_URL = $appUrl
    $env:WEB_SMOKE_REPORT_PATH = $smokeReportPath

    & node tools/ci_web_failure_smoke.js
    $smokeProbeExitCode = $LASTEXITCODE
    if ($smokeProbeExitCode -ne 0) {
      Write-Host "[stage-fail] smoke probe exit=$smokeProbeExitCode"
    }
  }
  catch {
    $smokeProbeExitCode = 1
    Write-Host "[stage-fail] smoke probe exception: $($_.Exception.Message)"
  }
  finally {
    if ($null -ne $server) {
      Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
  }

  if ($smokeProbeExitCode -eq 0 -and -not (Test-Path $smokeReportPath)) {
    $smokeProbeExitCode = 1
    Write-Host '[stage-fail] smoke probe did not produce report file'
  }

  if ($smokeProbeExitCode -ne 0) {
    Add-StageResult -Stage 'smoke_probe' -Status 'failed' -ReasonCode 'probe_failure' -ExitCode $smokeProbeExitCode
  } else {
    Add-StageResult -Stage 'smoke_probe' -Status 'success' -ReasonCode 'none' -ExitCode $smokeProbeExitCode
  }

  if (-not (Test-Path $smokeReportPath)) {
    $smokeFallback = [ordered]@{
      contractVersion = 'web_smoke_report_v1'
      status = 'FAIL'
      reason = 'probe_failure'
      scenarios = @()
    }
    Write-Utf8NoBom -Path $smokeReportPath -Content ($smokeFallback | ConvertTo-Json -Depth 10)
  }

  Write-Stage 'Build developer environment contract'
  $runId = if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) { [string]$env:GITHUB_RUN_ID } else { 'local' }
  $devEnvironmentContractExitCode = Invoke-PowerShellScript -ScriptPath 'tools/build_dev_environment_contract.ps1' -Arguments @(
    '-OutputPath', $devEnvironmentContractPath,
    '-SettingsPath', '.vscode/settings.json',
    '-RunId', $runId
  ) -AllowFailure
  if ($devEnvironmentContractExitCode -ne 0) {
    Write-Host "[stage-fail] build_dev_environment_contract exit=$devEnvironmentContractExitCode"
    Add-StageResult -Stage 'build_dev_environment_contract' -Status 'failed' -ReasonCode 'probe_failure' -ExitCode $devEnvironmentContractExitCode
  } else {
    Add-StageResult -Stage 'build_dev_environment_contract' -Status 'success' -ReasonCode 'none' -ExitCode $devEnvironmentContractExitCode
  }

  if (Test-Path $devEnvironmentContractPath) {
    $localHash = (Get-FileHash -Path $devEnvironmentContractPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Utf8NoBom -Path $localDevEnvironmentHashPath -Content ("sha256:" + $localHash)
  }

  if (-not [string]::IsNullOrWhiteSpace($env:MIXVY_CI_DEV_CONTRACT_HASH)) {
    Write-Utf8NoBom -Path $ciDevEnvironmentHashPath -Content ([string]$env:MIXVY_CI_DEV_CONTRACT_HASH)
  }

  Write-Stage 'Build deployment contract'
  if (Test-Path $currentHashPath) {
    $currentHash = (Get-Content -Path $currentHashPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($currentHash)) {
      Write-Utf8NoBom -Path $previousHashPath -Content $currentHash
    }
  }

  $contractBuildExitCode = Invoke-PowerShellScript -ScriptPath 'tools/build_deployment_contract.ps1' -Arguments @(
    '-Port', "$Port",
    '-StartupProbeReportPath', $startupReportPath,
    '-SmokeProbeReportPath', $smokeReportPath,
    '-PreflightContractPath', $preflightContractPath,
    '-PreviousHashPath', $previousHashPath,
    '-OutputPath', $contractPath
  ) -AllowFailure
  if ($contractBuildExitCode -ne 0) {
    Write-Host "[stage-fail] build_deployment_contract exit=$contractBuildExitCode"
    Add-StageResult -Stage 'build_deployment_contract' -Status 'failed' -ReasonCode 'probe_failure' -ExitCode $contractBuildExitCode
  } else {
    Add-StageResult -Stage 'build_deployment_contract' -Status 'success' -ReasonCode 'none' -ExitCode $contractBuildExitCode
  }

  Write-Stage 'Evaluate contract'
  $evaluateExitCode = Invoke-PowerShellScript -ScriptPath 'tools/evaluate_deployment_contract.ps1' -Arguments @(
    '-ContractPath', $contractPath,
    '-SchemaPath', 'tools/deployment_contract.schema.json',
    '-OutputPath', $evaluationPath,
    '-ResolvedContractPath', $resolvedContractPath,
    '-CurrentHashPath', $currentHashPath,
    '-DevEnvironmentContractPath', $devEnvironmentContractPath,
    '-LocalDevContractHashPath', $localDevEnvironmentHashPath,
    '-CiDevContractHashPath', $ciDevEnvironmentHashPath
  ) -AllowFailure
  if ($evaluateExitCode -ne 0) {
    Add-StageResult -Stage 'evaluate_deployment_contract' -Status 'failed' -ReasonCode 'policy_rejection' -ExitCode $evaluateExitCode
  } else {
    Add-StageResult -Stage 'evaluate_deployment_contract' -Status 'success' -ReasonCode 'none' -ExitCode $evaluateExitCode
  }

  if (-not (Test-Path $resolvedContractPath)) {
    throw 'Missing resolved contract output.'
  }

  if (-not (Test-Path $evaluationPath)) {
    throw 'Missing evaluation output.'
  }

  $evaluation = Get-Content -Path $evaluationPath -Raw | ConvertFrom-Json

  $contract = Get-Content -Path $resolvedContractPath -Raw | ConvertFrom-Json

  if ($contract.governance.decision -ne 'allow') {
    Write-Host "DEPLOYMENT BLOCKED: $($contract.governance.reasonCode)"

    Persist-AuditHistory -Root $DeployRoot -ContractFile $contractPath -ResolvedFile $resolvedContractPath -EvaluationFile $evaluationPath -DevEnvironmentContractFile $devEnvironmentContractPath -ResolvedContract $contract

    Write-Host ''
    Write-Host 'Release Summary:'
    Write-Host "- Decision: $($contract.governance.decision)"
    Write-Host "- ReasonCode: $($contract.governance.reasonCode)"
    Write-Host "- Contract Hash: $($contract.contractHash)"
    Write-Host "- Previous Hash: $($contract.previousContractHash)"
    Write-Host "- Environment: $($contract.environment.class)"
    Write-Host "- Stage Exit Codes: reset=$resetExitCode preflight=$preflightExitCode build=$buildExitCode startupProbe=$startupProbeExitCode smokeProbe=$smokeProbeExitCode devEnvironment=$devEnvironmentContractExitCode contractBuild=$contractBuildExitCode evaluate=$evaluateExitCode"
    Write-Host ''
    Write-ReleaseTelemetryFooter -Evaluation $evaluation

    exit 1
  }

  Write-Stage 'Deploy release'
  $releaseHash = [string]$contract.contractHash
  if ([string]::IsNullOrWhiteSpace($releaseHash)) {
    throw 'Resolved contract hash is empty.'
  }

  $releasesDir = Join-Path $DeployRoot 'releases'
  $releaseDir = Join-Path $releasesDir $releaseHash
  $currentDir = Join-Path $DeployRoot 'current'
  $currentTempDir = Join-Path $DeployRoot 'current_new'

  New-Item -ItemType Directory -Path $releasesDir -Force | Out-Null

  if (Test-Path $releaseDir) {
    Remove-Item -Path $releaseDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
  Copy-Item -Path (Join-Path $BuildPath '*') -Destination $releaseDir -Recurse -Force

  if (Test-Path $currentTempDir) {
    Remove-Item -Path $currentTempDir -Recurse -Force
  }
  Copy-Item -Path $releaseDir -Destination $currentTempDir -Recurse -Force

  if (Test-Path $currentDir) {
    Remove-Item -Path $currentDir -Recurse -Force
  }
  Rename-Item -Path $currentTempDir -NewName 'current'

  Persist-AuditHistory -Root $DeployRoot -ContractFile $contractPath -ResolvedFile $resolvedContractPath -EvaluationFile $evaluationPath -DevEnvironmentContractFile $devEnvironmentContractPath -ResolvedContract $contract

  Write-Host 'DEPLOY SUCCESS'
  Write-Host "contractHash: $($contract.contractHash)"
  Write-Host "previousHash: $($contract.previousContractHash)"

  Write-Host ''
  Write-Host 'Release Summary:'
  Write-Host "- Decision: $($contract.governance.decision)"
  Write-Host "- ReasonCode: $($contract.governance.reasonCode)"
  Write-Host "- Contract Hash: $($contract.contractHash)"
  Write-Host "- Previous Hash: $($contract.previousContractHash)"
  Write-Host "- Environment: $($contract.environment.class)"
  Write-Host "- Stage Exit Codes: reset=$resetExitCode preflight=$preflightExitCode build=$buildExitCode startupProbe=$startupProbeExitCode smokeProbe=$smokeProbeExitCode devEnvironment=$devEnvironmentContractExitCode contractBuild=$contractBuildExitCode evaluate=$evaluateExitCode"
  Write-Host ''
  Write-ReleaseTelemetryFooter -Evaluation $evaluation
}
catch {
  Write-Host "DEPLOYMENT FAILED: $($_.Exception.Message)"
  exit 1
}
