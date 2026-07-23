<#
.SYNOPSIS
  Records a minimal per-RC observation entry to rc_observation_log.json.

.DESCRIPTION
  Reads only the three defined observation signals:
    1. Identity eligibility  — SHA256 hash comparison against governance-v1-lock baseline
    2. Contract validity     — policy_contract_validation_status.json status field
    3. Control-plane state   — policy_tuner_status.json artifact_mode + inBurnInFreeze

  Appends a single structured record to tools/reports/rc_observation_log.json.
  Does NOT modify any governance artifact. Does NOT make any tuning or threshold changes.

.PARAMETER RcId
  RC identifier (e.g. 'rc-1.0.0-001'). Required.

.PARAMETER Notes
  Optional free-text observation note for this run.

.EXAMPLE
  .\record_rc_observation.ps1 -RcId 'rc-1.0.0-001'
  .\record_rc_observation.ps1 -RcId 'rc-1.0.0-002' -Notes 'First run after prod smoke test'
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$RcId,

    [string]$Notes = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ReportsDir = Join-Path $PSScriptRoot 'reports'
$LogFile    = Join-Path $ReportsDir 'rc_observation_log.json'

# ---------------------------------------------------------------------------
# Baseline hashes anchored at governance-v1-lock (commit 8de1d52, 2026-04-13)
# These must never be updated here — any change requires a new version tag.
# ---------------------------------------------------------------------------
$LOCK_BASELINE = @{
    'tools/release_governor_policy.json'       = '8D51CC44340D884542F6F7F75AE579CB153380F0E7B8ECBDD9F1E9B9842FAF6B'
    'tools/release_governor_safety_floors.json' = '421153B8306A72F7A9F4B0D3C80E52287F5959C952B92FD76D9441D9A7A8D8D1'
    'tools/policy_drift_contract.schema.json'   = 'FC76FA2C11CFBD663C9AB4DA38FEB0F49FBCB4450B6B5217258AC7A00FE2D842'
}

$WorkspaceRoot = Split-Path $PSScriptRoot -Parent

# ---------------------------------------------------------------------------
# Signal 1: Identity eligibility
# ---------------------------------------------------------------------------
$identityEligible = $true
$hashMismatches   = @()

foreach ($relativePath in $LOCK_BASELINE.Keys) {
    $fullPath     = Join-Path $WorkspaceRoot $relativePath
    $expectedHash = $LOCK_BASELINE[$relativePath]

    if (-not (Test-Path $fullPath)) {
        $hashMismatches += "$relativePath (file not found)"
        $identityEligible = $false
        continue
    }

    $actualHash = (Get-FileHash $fullPath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        $hashMismatches += "$relativePath (expected $expectedHash, got $actualHash)"
        $identityEligible = $false
    }
}

# ---------------------------------------------------------------------------
# Signal 2: Contract validity
# ---------------------------------------------------------------------------
$contractStatus     = 'unknown'
$contractStatusFile = Join-Path $ReportsDir 'policy_contract_validation_status.json'

if (Test-Path $contractStatusFile) {
    try {
        $contractArtifact = Get-Content $contractStatusFile -Raw | ConvertFrom-Json
        $contractStatus   = $contractArtifact.status
    } catch {
        $contractStatus = 'parse_error'
    }
} else {
    $contractStatus = 'artifact_missing'
}

$contractValid = ($contractStatus -eq 'passed')

# ---------------------------------------------------------------------------
# Signal 3: Control-plane state
# ---------------------------------------------------------------------------
$tunerState      = 'unknown'
$artifactMode    = 'unknown'
$inBurnInFreeze  = $null
$tunerStatusFile = Join-Path $ReportsDir 'policy_tuner_status.json'

if (Test-Path $tunerStatusFile) {
    try {
        $tunerArtifact  = Get-Content $tunerStatusFile -Raw | ConvertFrom-Json
        $tunerState     = $tunerArtifact.status
        $artifactMode   = $tunerArtifact.artifact_mode
        $inBurnInFreeze = [bool]$tunerArtifact.inBurnInFreeze
    } catch {
        $tunerState = 'parse_error'
    }
} else {
    $tunerState = 'artifact_missing'
}

# ---------------------------------------------------------------------------
# Build record
# ---------------------------------------------------------------------------
$record = [ordered]@{
    rc_id              = $RcId
    timestamp          = (Get-Date -Format 'o')
    governance_lock    = 'governance-v1-lock'
    identity_eligible  = $identityEligible
    hash_mismatches    = $hashMismatches
    contract_valid     = $contractValid
    contract_status    = $contractStatus
    tuner_state        = $tunerState
    artifact_mode      = $artifactMode
    inBurnInFreeze     = $inBurnInFreeze
    notes              = $Notes
}

# ---------------------------------------------------------------------------
# Append-only write to observation log
# ---------------------------------------------------------------------------
if (-not (Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir | Out-Null
}

$existing = @()
if (Test-Path $LogFile) {
    $raw = Get-Content $LogFile -Raw
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $parsed = $raw | ConvertFrom-Json
        # Normalize single-object result to array
        if ($parsed -is [System.Collections.IEnumerable] -and -not ($parsed -is [string])) {
            $existing = @($parsed)
        } else {
            $existing = @($parsed)
        }
    }
}

$existing += $record
$existing | ConvertTo-Json -Depth 6 | Set-Content $LogFile -Encoding UTF8

# ---------------------------------------------------------------------------
# Console summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "RC Observation recorded: $RcId" -ForegroundColor Cyan
Write-Host "------------------------------------------"
Write-Host "  Identity eligible : $($identityEligible.ToString().ToUpper())"  -ForegroundColor $(if ($identityEligible) { 'Green' } else { 'Yellow' })
Write-Host "  Contract valid    : $($contractValid.ToString().ToUpper())"     -ForegroundColor $(if ($contractValid)     { 'Green' } else { 'Red'    })
Write-Host "  Tuner state       : $tunerState"
Write-Host "  Artifact mode     : $artifactMode"
Write-Host "  Burn-in freeze    : $inBurnInFreeze"

if ($hashMismatches.Count -gt 0) {
    Write-Host ""
    Write-Host "  HASH MISMATCHES (run does not count toward stability gate):" -ForegroundColor Yellow
    foreach ($m in $hashMismatches) { Write-Host "    - $m" -ForegroundColor Yellow }
}

Write-Host ""
Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
Write-Host ""

if (-not $identityEligible) {
    Write-Host "NOTE: identity mismatch detected — this run is flagged non-comparable." -ForegroundColor Yellow
    Write-Host "      CI diagnostics are still valid. Run does NOT count toward verification gate." -ForegroundColor Yellow
}
