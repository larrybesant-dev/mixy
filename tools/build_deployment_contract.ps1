param(
  [int]$Port = 8080,
  [string]$StartupProbeReportPath = 'tools/reports/startup_probe_report.json',
  [string]$SmokeProbeReportPath = 'tools/reports/web_failure_smoke_report.json',
  [string]$PreflightContractPath = 'artifacts/preflight_contract.json',
  [string]$PreviousHashPath = 'artifacts/hash_chain/previous_contract_hash.txt',
  [string]$OutputPath = 'artifacts/deployment_contract.json'
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )

  New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force | Out-Null
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-OsClass {
  if ($env:RUNNER_OS) {
    switch ($env:RUNNER_OS.ToLowerInvariant()) {
      'windows' { return 'windows' }
      'linux' { return 'linux' }
      'macos' { return 'macos' }
    }
  }

  if ($IsWindows) { return 'windows' }
  if ($IsLinux) { return 'linux' }
  if ($IsMacOS) { return 'macos' }
  return 'windows'
}

function Resolve-EnvironmentClass {
  param($PreflightContract)

  if ($null -ne $PreflightContract -and $null -ne $PreflightContract.environment) {
    $candidate = [string]$PreflightContract.environment.class
    if ($candidate -in @('ci', 'local', 'unknown')) {
      return $candidate
    }
  }

  return 'unknown'
}

function Resolve-PrivilegeClass {
  param($PreflightContract)

  if ($null -ne $PreflightContract -and $null -ne $PreflightContract.environment) {
    $candidate = [string]$PreflightContract.environment.privilegeClass
    if ($candidate -in @('admin', 'non-admin', 'restricted')) {
      return $candidate
    }
  }

  return 'restricted'
}

function Resolve-PortOwnership {
  param($PreflightContract)

  if ($null -eq $PreflightContract -or $null -eq $PreflightContract.preflight) {
    return 'unknown'
  }

  $finalListeners = @($PreflightContract.preflight.finalListeners)
  if ($finalListeners.Count -eq 0) {
    return 'user'
  }

  foreach ($listener in $finalListeners) {
    $ownership = [string]$listener.ownership
    if ($ownership -in @('kernel_listener', 'system_service')) {
      return 'system'
    }
    if ($ownership -eq 'service') {
      return 'service'
    }
  }

  return 'user'
}

function Get-ProbeStatus {
  param($Report)

  if ($null -eq $Report) {
    return 'fail'
  }

  $status = [string]$Report.status
  if ($status.ToUpperInvariant() -eq 'PASS') {
    return 'pass'
  }

  return 'fail'
}

function Read-JsonIfPresent {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return $null
  }

  try {
    return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
  } catch {
    return $null
  }
}

$startupReport = Read-JsonIfPresent -Path $StartupProbeReportPath
$smokeReport = Read-JsonIfPresent -Path $SmokeProbeReportPath
$preflightContract = Read-JsonIfPresent -Path $PreflightContractPath

$startupContractVersion = 'unknown'
$startupReady = $false
$startupCheckpoints = @()
if ($null -ne $startupReport -and $null -ne $startupReport.finalContract) {
  $startupContractVersion = [string]$startupReport.finalContract.contractVersion
  if ([string]::IsNullOrWhiteSpace($startupContractVersion)) {
    $startupContractVersion = 'unknown'
  }

  $startupReady = [bool]$startupReport.finalContract.ready

  if ($null -ne $startupReport.finalContract.checkpoints) {
    $startupCheckpoints = @($startupReport.finalContract.checkpoints.PSObject.Properties.Name | Sort-Object)
  }
}

$environmentClass = Resolve-EnvironmentClass -PreflightContract $preflightContract
$privilegeClass = Resolve-PrivilegeClass -PreflightContract $preflightContract
$portOwnership = Resolve-PortOwnership -PreflightContract $preflightContract

$startupProbeStatus = Get-ProbeStatus -Report $startupReport
$smokeProbeStatus = Get-ProbeStatus -Report $smokeReport

$previousContractHash = $null
if (Test-Path $PreviousHashPath) {
  try {
    $rawHash = (Get-Content -Path $PreviousHashPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($rawHash)) {
      $previousContractHash = $rawHash
    }
  } catch {
    $previousContractHash = $null
  }
}

$contract = [ordered]@{
  authority = [ordered]@{
    runtime = 'flutter'
    ci = 'github-actions'
    resolvedBy = 'deployment_contract'
  }
  contractState = 'INIT'
  contractHash = 'unknown'
  previousContractHash = $previousContractHash
  artifact = [ordered]@{
    commitSha = if ([string]::IsNullOrWhiteSpace($env:GITHUB_SHA)) {
      try { (& git rev-parse HEAD 2>$null).Trim() } catch { 'unknown' }
    } else {
      $env:GITHUB_SHA
    }
    buildId = if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_RUN_NUMBER)) { $env:GITHUB_RUN_NUMBER } else { 'unknown' }
    workflowRunId = if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) { $env:GITHUB_RUN_ID } else { 'unknown' }
  }
  startup = [ordered]@{
    contractVersion = $startupContractVersion
    ready = $startupReady
    checkpoints = @($startupCheckpoints)
  }
  environment = [ordered]@{
    class = $environmentClass
    os = Get-OsClass
  }
  privilege = [ordered]@{
    class = $privilegeClass
  }
  networking = [ordered]@{
    port = $Port
    portOwnership = $portOwnership
  }
  probeResults = [ordered]@{
    startupProbe = $startupProbeStatus
    smokeProbe = $smokeProbeStatus
  }
  governance = [ordered]@{
    decision = 'deny'
    reasonCode = 'schema_invalid'
  }
}

New-Item -ItemType Directory -Path (Split-Path -Path $OutputPath -Parent) -Force | Out-Null
$json = $contract | ConvertTo-Json -Depth 10
Write-Utf8NoBom -Path $OutputPath -Content $json
Write-Host "[deployment-contract] Wrote $OutputPath"
