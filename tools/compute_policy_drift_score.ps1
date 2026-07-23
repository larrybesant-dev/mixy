<#
.SYNOPSIS
Computes hierarchical Policy Drift Score from multi-plane governance artifacts.

.DESCRIPTION
Reduces three independent metric spaces (replay, boundary drift, surface diff) 
into single CI-gateable decision variable via hierarchical weighting.

CRITICAL: This is lossy compression of policy manifold -> CI gate.
Strict hierarchy: S (primary) > T (modifier) > E (modifier).

Metrics:
  S = exitSetJaccard (structural similarity, primary stability axis)
  T = differingThresholdCount / sweepSize (boundary fragmentation)
  E = entryCountDelta / maxHistoryDepth (temporal drift)

Formula:
    DriftScore = 100 * (1 - S) + alpha*T + beta*E
    where alpha = 25, beta = 15

Tier logic (prevent scalar hiding catastrophic shifts):
  Hard Fail:  Jaccard < 0.7 (surface divergence)
  Soft Fail:  DriftScore > threshold (default 45)
  Pass:       All conditions met

.PARAMETER ReplayPath
Path to replay_timeline.json (sweep mode with invariants)

.PARAMETER BoundaryDriftPath
Path to boundary_drift_analysis.json

.PARAMETER PolicySurfaceDiffPath
Path to policy_surface_diff.json

.PARAMETER OutputPath
Path to write computed score artifact

.PARAMETER DriftScoreThreshold
Soft-fail threshold for DriftScore (default 45)

#>
param(
    [string]$ReplayPath = "tools/reports/replay_timeline.json",
    [string]$BoundaryDriftPath = "tools/reports/boundary_drift_analysis.json",
    [string]$PolicySurfaceDiffPath = "tools/reports/policy_surface_diff.json",
    [string]$OutputPath = "tools/reports/policy_drift_score.json",
    [int]$DriftScoreThreshold = 45
)

$ErrorActionPreference = "Stop"

function Invoke-SafeJsonRead {
    param([string]$Path, [string]$Label)
    
    if (-not (Test-Path $Path)) {
        throw "Required artifact not found: $Label @ $Path"
    }
    
    try {
        $content = Get-Content -Path $Path -Raw
        return $content | ConvertFrom-Json
    } catch {
        throw "Failed to parse $Label from $Path : $_"
    }
}

# Load all three artifacts
Write-Output "Loading governance artifacts..."
$replay = Invoke-SafeJsonRead -Path $ReplayPath -Label "Replay Timeline"
$boundaryDrift = Invoke-SafeJsonRead -Path $BoundaryDriftPath -Label "Boundary Drift Analysis"
$surfaceDiff = Invoke-SafeJsonRead -Path $PolicySurfaceDiffPath -Label "Policy Surface Diff"

# Extract metric components
Write-Output "Extracting metric components..."

# Primary axis: Structural similarity (Jaccard from surface diff)
$jaccard = $surfaceDiff.summary.exitSetJaccard
if ($null -eq $jaccard -or $jaccard -lt 0 -or $jaccard -gt 1) {
    throw "Invalid Jaccard metric: $jaccard (expected 0..1)"
}

# Secondary axis: Boundary fragmentation
$differingThresholdCount = $surfaceDiff.summary.differingThresholdCount
if ($null -eq $differingThresholdCount -or $differingThresholdCount -lt 0) {
    throw "Invalid differingThresholdCount: $differingThresholdCount"
}

# Extract sweep size from replay to normalize T
$sweepSize = $replay.invariants.scannedThresholdCount
if ($null -eq $sweepSize -or $sweepSize -le 0) {
    throw "Invalid sweepSize from replay invariants: $sweepSize"
}

# Tertiary axis: Temporal drift
$entryCountDelta = $surfaceDiff.summary.entryCountDelta
if ($null -eq $entryCountDelta) {
    $entryCountDelta = 0  # Could be missing in some runs
}

# Max history depth (from boundary drift latest entry)
$maxHistoryDepth = $boundaryDrift.prefixes[-1].historyDepth
if ($null -eq $maxHistoryDepth -or $maxHistoryDepth -le 0) {
    $maxHistoryDepth = 1  # Fallback to avoid division by zero
}

# Compute normalized metrics
$S = $jaccard
$T = [double]$differingThresholdCount / $sweepSize
$E = [double][Math]::Abs($entryCountDelta) / $maxHistoryDepth

# Apply weights (hierarchy preserved)
$alpha = 25  # Boundary fragmentation weight
$beta = 15   # Temporal drift weight

$driftScore = 100 * (1 - $S) + $alpha * $T + $beta * $E

# Clamp to [0, 100] range
$driftScore = [Math]::Max(0, [Math]::Min(100, $driftScore))

# Determine tier classification
$hardFailReason = $null
$softFailReason = $null
$tierClassification = "pass"

# Hard fail condition: Surface divergence
if ($jaccard -lt 0.7) {
    $tierClassification = "hard_fail"
    $hardFailReason = "Surface divergence detected (Jaccard=$jaccard < 0.7)"
}

# Soft fail condition: Score exceeds threshold (only if hard fail not triggered)
if ($tierClassification -ne "hard_fail" -and $driftScore -gt $DriftScoreThreshold) {
    $tierClassification = "soft_fail"
    $softFailReason = "DriftScore=$driftScore exceeds threshold=$DriftScoreThreshold"
}

# Build output artifact
$now = [System.DateTime]::UtcNow.ToString("o")

$scoreArtifact = @{
    generatedAtUtc = $now
    scoreVersion = "policy_drift_score_v1"
    schemaVersion = "1.0.0"
    source = @{
        replayPath = $ReplayPath
        boundaryDriftPath = $BoundaryDriftPath
        policySurfaceDiffPath = $PolicySurfaceDiffPath
        replayEntryCount = $replay.source.entryCount
        boundaryDriftEntryCount = $boundaryDrift.source.entryCount
        diffHistoryAEntryCount = $surfaceDiff.source.historyA.entryCount
        diffHistoryBEntryCount = $surfaceDiff.source.historyB.entryCount
    }
    parameters = @{
        driftScoreThreshold = $DriftScoreThreshold
        alphaWeight = $alpha
        betaWeight = $beta
        formulaDescription = "100 * (1 - S) + alpha*T + beta*E where S=Jaccard (primary), T=Fragmentation (secondary), E=Drift (tertiary)"
    }
    components = @{
        structuralSimilarity = @{
            metric = "exitSetJaccard"
            value = $S
            role = "primary_axis"
            interpretation = "Policy surface similarity [0..1]"
        }
        boundaryFragmentation = @{
            metric = "differingThresholdCount_normalized"
            rawValue = $differingThresholdCount
            sweepSize = $sweepSize
            normalizedValue = $T
            role = "secondary_modifier"
            interpretation = "Fraction of thresholds with differing behavior"
        }
        temporalDrift = @{
            metric = "entryCountDelta_normalized"
            rawValue = $entryCountDelta
            maxHistoryDepth = $maxHistoryDepth
            normalizedValue = $E
            role = "tertiary_modifier"
            interpretation = "Relative change in history depth"
        }
    }
    summary = @{
        driftScore = $driftScore
        tier = $tierClassification
        hardFailReason = $hardFailReason
        softFailReason = $softFailReason
        recommendation = @{
            action = switch ($tierClassification) {
                "hard_fail" { "reject_with_review" }
                "soft_fail" { "gate_pending_review" }
                "pass" { "proceed_with_observation" }
                default { "unknown" }
            }
            explanation = switch ($tierClassification) {
                "hard_fail" { "Policy surface has diverged significantly. Manual review required before proceeding." }
                "soft_fail" { "Policy surface shows drift. Recommend review of governance thresholds before release." }
                "pass" { "Policy surface stable and consistent. Gating conditions met." }
                default { "Unknown tier classification state." }
            }
        }
    }
    breakdown = @{
        formula = "DriftScore = 100 * (1 - $S) + $alpha * $T + $beta * $E"
        componentContribution = @{
            structuralTerm = 100 * (1 - $S)
            boundaryTerm = $alpha * $T
            temporalTerm = $beta * $E
            total = $driftScore
        }
    }
}

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

# Write artifact
$scoreArtifact | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
Write-Output "Policy Drift Score computed and written to: $OutputPath"
Write-Output ""
Write-Output "=== POLICY DRIFT SCORE SUMMARY ==="
Write-Output "Score: $driftScore / 100"
Write-Output "Tier: $tierClassification"
if ($hardFailReason) { Write-Output "Hard Fail Reason: $hardFailReason" }
if ($softFailReason) { Write-Output "Soft Fail Reason: $softFailReason" }
Write-Output "Recommendation: $(($scoreArtifact.summary.recommendation).action)"
Write-Output ""
Write-Output "=== COMPONENT BREAKDOWN ==="
Write-Output "Structural Similarity (S, primary): $S"
Write-Output "Boundary Fragmentation (T, secondary): $T"
Write-Output "Temporal Drift (E, tertiary): $E"
Write-Output ""
Write-Output "=== CONTRIBUTION ANALYSIS ==="
Write-Output "Structural term (100 * (1-S)): $([Math]::Round(100 * (1 - $S), 2))"
Write-Output "Boundary term ($alpha * T): $([Math]::Round($alpha * $T, 2))"
Write-Output "Temporal term ($beta * E): $([Math]::Round($beta * $E, 2))"
Write-Output "Final DriftScore: $driftScore"

# Output JSON for machine parsing
$scoreArtifact | ConvertTo-Json -Depth 10
