<#
.SYNOPSIS
  Checks whether an RC-to-RC transition is isolated or shows cascade drift.

.DESCRIPTION
  Compares two records in tools/reports/rc_observation_log.json and classifies
  the transition under the governance model:
    - pre_transition_invariant
    - isolated_burnin_transition
    - cascade_drift
    - uncontrolled_drift

  Allowed isolated change for RC-6 boundary:
    inBurnInFreeze: true -> false

  All other tracked fields must remain unchanged.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$FromRcId,

    [Parameter(Mandatory = $true)]
    [string]$ToRcId,

    [string]$LogFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $LogFile = Join-Path (Join-Path $PSScriptRoot 'reports') 'rc_observation_log.json'
}

if (-not (Test-Path $LogFile)) {
    throw "Observation log not found: $LogFile"
}

$log = Get-Content $LogFile -Raw | ConvertFrom-Json
if (-not $log) {
    throw "Observation log is empty: $LogFile"
}

$from = $log | Where-Object { $_.rc_id -eq $FromRcId } | Select-Object -First 1
$to   = $log | Where-Object { $_.rc_id -eq $ToRcId }   | Select-Object -First 1

if (-not $from) { throw "FromRcId not found: $FromRcId" }
if (-not $to)   { throw "ToRcId not found: $ToRcId" }

$fields = @(
    'identity_eligible',
    'contract_valid',
    'contract_status',
    'tuner_state',
    'artifact_mode',
    'inBurnInFreeze',
    'hash_mismatches',
    'notes'
)

$changes = @()
foreach ($f in $fields) {
    $left  = $from.$f
    $right = $to.$f

    # Normalize arrays for stable comparison
    if ($left -is [System.Array])  { $left  = ($left | ForEach-Object { [string]$_ }) -join '|' }
    if ($right -is [System.Array]) { $right = ($right | ForEach-Object { [string]$_ }) -join '|' }

    if ([string]$left -ne [string]$right) {
        $changes += [pscustomobject]@{
            field = $f
            from  = [string]$left
            to    = [string]$right
        }
    }
}

$classification = 'uncontrolled_drift'
$reason = ''

if ($changes.Count -eq 0) {
    $classification = 'pre_transition_invariant'
    $reason = 'No tracked field changed.'
}
else {
    $burnInChange = $changes | Where-Object { $_.field -eq 'inBurnInFreeze' } | Select-Object -First 1
    $otherChanges = $changes | Where-Object { $_.field -ne 'inBurnInFreeze' }

    if ($burnInChange -and $burnInChange.from -eq 'True' -and $burnInChange.to -eq 'False') {
        if ($otherChanges.Count -eq 0) {
            $classification = 'isolated_burnin_transition'
            $reason = 'Only inBurnInFreeze changed True -> False.'
        }
        else {
            $classification = 'cascade_drift'
            $reason = 'Burn-in boundary change caused additional field changes.'
        }
    }
    elseif ($burnInChange -and $otherChanges.Count -gt 0) {
        $classification = 'cascade_drift'
        $reason = 'inBurnInFreeze changed with additional field changes.'
    }
    else {
        $classification = 'uncontrolled_drift'
        $reason = 'Fields changed without expected isolated burn-in transition.'
    }
}

$result = [ordered]@{
    from_rc        = $FromRcId
    to_rc          = $ToRcId
    classification = $classification
    reason         = $reason
    changed_fields = $changes
}

$result | ConvertTo-Json -Depth 6
