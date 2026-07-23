param(
  [int[]]$Ports = @(8080, 9090),
  [switch]$IncludeFlutterClean
)

$ErrorActionPreference = 'Stop'

function Write-Info {
  param([string]$Message)
  Write-Host "[dev-reset] $Message"
}

$results = @()

foreach ($port in $Ports) {
  Write-Info "Running deterministic port preflight cleanup for port $port"
  $preflightContractPath = "artifacts/preflight_contract.reset.$port.json"
  & powershell -ExecutionPolicy Bypass -File tools/port_preflight_guard.ps1 -Port $port -Mode Force -TimeoutSeconds 45 -StabilizationSeconds 3 -OutputPath $preflightContractPath
  $exitCode = $LASTEXITCODE

  $preflightStatus = 'failed'
  $preflightReason = 'probe_failure'
  if ($exitCode -eq 0 -and (Test-Path $preflightContractPath)) {
    try {
      $preflightContract = Get-Content -Path $preflightContractPath -Raw | ConvertFrom-Json
      $preflightStatus = [string]$preflightContract.status
      $preflightReason = [string]$preflightContract.reasonCode
      if ([string]::IsNullOrWhiteSpace($preflightReason)) {
        $preflightReason = 'none'
      }
    } catch {
      $preflightStatus = 'failed'
      $preflightReason = 'schema_invalid'
    }
  }

  $result = [ordered]@{
    port = $port
    preflightExitCode = $exitCode
    preflightStatus = $preflightStatus
    reasonCode = $preflightReason
    released = ($exitCode -eq 0 -and $preflightStatus -eq 'pass')
  }
  $results += $result

  if (-not $result.released) {
    Write-Info "Failed to release port $port (status=$preflightStatus reason=$preflightReason). Check blocking ownership and privileges."
  }
}

if ($IncludeFlutterClean) {
  Write-Info 'Running flutter clean and flutter pub get'
  flutter clean
  if ($LASTEXITCODE -ne 0) {
    throw 'flutter clean failed during dev reset.'
  }

  flutter pub get
  if ($LASTEXITCODE -ne 0) {
    throw 'flutter pub get failed during dev reset.'
  }
}

$summary = [ordered]@{
  contractVersion = 'mixvy.dev_reset_report.v1'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  results = $results
}

$summaryPath = 'tools/reports/dev_reset_report.json'
New-Item -ItemType Directory -Path 'tools/reports' -Force | Out-Null
$summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding utf8

$failed = $results | Where-Object { -not $_.released }
if ($failed.Count -gt 0) {
  Write-Info "Dev reset incomplete. See $summaryPath"
  exit 1
}

Write-Info "Dev reset completed successfully. See $summaryPath"
exit 0
