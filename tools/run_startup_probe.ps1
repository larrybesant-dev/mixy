param(
  [ValidateSet('startup', 'smoke')]
  [string]$Mode,
  [switch]$SkipPreflight,
  [int]$Port = 9090,
  [string]$BuildPath = 'build/web',
  [string]$AppUrl = 'http://127.0.0.1:9090/',
  [int]$ServerReadyTimeoutSeconds = 45,
  [string]$StartupLogPath = 'tools/reports/startup_timeline.log',
  [string]$StartupReportPath = 'tools/reports/startup_probe_report.json',
  [string]$WebSmokeReportPath = 'tools/reports/web_failure_smoke_report.json'
)

$ErrorActionPreference = 'Stop'

function Write-Info {
  param([string]$Message)
  Write-Host "[startup-probe] $Message"
}

function Invoke-NodeScript {
  param([string]$ScriptPath)

  & node $ScriptPath
  if ($LASTEXITCODE -ne 0) {
    throw "Node script failed: $ScriptPath (exit=$LASTEXITCODE)"
  }
}

$envInfoRaw = & powershell -ExecutionPolicy Bypass -File tools/detect_execution_environment.ps1 -JsonOnly
$envInfo = $envInfoRaw | ConvertFrom-Json
$isCi = ([string]$envInfo.environment -eq 'ci')
$preflightMode = if ($isCi) { 'Force' } else { 'Safe' }

Write-Info "Environment=$($envInfo.environment) Admin=$($envInfo.isAdmin) Mode=$Mode"
if (-not $SkipPreflight) {
  Write-Info "Running preflight guard for port $Port using mode $preflightMode"

  $preflightContractPath = "artifacts/preflight_contract.startup_probe.$Port.json"
  & powershell -ExecutionPolicy Bypass -File tools/port_preflight_guard.ps1 -Port $Port -Mode $preflightMode -TimeoutSeconds 45 -StabilizationSeconds 3 -OutputPath $preflightContractPath
  if ($LASTEXITCODE -ne 0) {
    throw "Port preflight execution failed for port $Port (exit=$LASTEXITCODE)"
  }

  if (-not (Test-Path $preflightContractPath)) {
    throw "Port preflight did not produce contract output: $preflightContractPath"
  }

  $preflightContract = Get-Content -Path $preflightContractPath -Raw | ConvertFrom-Json
  if ([string]$preflightContract.status -ne 'pass') {
    $reason = [string]$preflightContract.reasonCode
    if ([string]::IsNullOrWhiteSpace($reason)) {
      $reason = 'probe_failure'
    }
    throw "Port preflight classified port $Port as blocked ($reason)"
  }
} else {
  Write-Info "Skipping embedded preflight guard (external preflight stage expected)."
}

if (-not (Test-Path $BuildPath)) {
  throw "Build path does not exist: $BuildPath"
}

$server = $null
try {
  Write-Info "Starting static server on http://127.0.0.1:$Port"
  $server = Start-Process npx -ArgumentList 'http-server', $BuildPath, '-p', $Port, '-a', '127.0.0.1', '-s' -PassThru

  $ready = $false
  for ($i = 0; $i -lt $ServerReadyTimeoutSeconds; $i++) {
    try {
      Invoke-WebRequest -Uri $AppUrl -UseBasicParsing | Out-Null
      $ready = $true
      break
    } catch {
      Start-Sleep -Seconds 1
    }
  }

  if (-not $ready) {
    throw "Static web server did not become ready within timeout ($ServerReadyTimeoutSeconds s)."
  }

  $env:STARTUP_APP_URL = $AppUrl
  $env:STARTUP_LOG_PATH = $StartupLogPath
  $env:STARTUP_PROBE_REPORT_PATH = $StartupReportPath
  $env:WEB_SMOKE_REPORT_PATH = $WebSmokeReportPath

  if ($Mode -eq 'startup') {
    Invoke-NodeScript -ScriptPath 'tools/ci_capture_startup_log.js'
  } else {
    Invoke-NodeScript -ScriptPath 'tools/ci_web_failure_smoke.js'
  }

  Write-Info "Probe mode '$Mode' completed successfully."
} finally {
  if ($null -ne $server) {
    try {
      Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
      Write-Info "Stopped static server PID=$($server.Id)"
    } catch {
      Write-Info "Failed to stop static server cleanly: $($_.Exception.Message)"
    }
  }
}
