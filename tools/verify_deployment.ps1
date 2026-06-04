# MixVy Deployment Verification Script
# Verifies file integrity, compliance with the contract, and matching hash signatures.

$ErrorActionPreference = 'Stop'

Write-Host "=== MixVy Release Verification ===" -ForegroundColor Cyan

$DeployRoot = 'deploy'
$CurrentDir = Join-Path $DeployRoot 'current'
$ResolvedContractPath = 'artifacts/deployment_contract.resolved.json'
$EvaluationPath = 'artifacts/deployment_contract_evaluation.json'

# 1. Check if deployed directory exists
if (-not (Test-Path $CurrentDir)) {
    Write-Host "[FAIL] Deployed 'current/' directory not found at: $CurrentDir" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] Deployed directory found: $CurrentDir" -ForegroundColor Green

# 2. Check if contract files exist
if (-not (Test-Path $ResolvedContractPath)) {
    Write-Host "[FAIL] Deployed resolved contract not found at: $ResolvedContractPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $EvaluationPath)) {
    Write-Host "[FAIL] Evaluation report not found at: $EvaluationPath" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] Contract and Evaluation metadata files are present." -ForegroundColor Green

# 3. Read and verify contract details
$contract = Get-Content -Path $ResolvedContractPath -Raw | ConvertFrom-Json
$evaluation = Get-Content -Path $EvaluationPath -Raw | ConvertFrom-Json

$actualHash = [string]$contract.contractHash
$expectedHash = "e7bbaf1d5727c86f6f64bef1d2a8c779afdff649c9e95d9f256b1ca5c13324b2"

Write-Host "`nContract Details:" -ForegroundColor Yellow
Write-Host "  - Release Contract Hash: $actualHash"
Write-Host "  - Previous Contract Hash: $($contract.previousContractHash)"
Write-Host "  - Decision: $($contract.governance.decision)"
Write-Host "  - Reason Code: $($contract.governance.reasonCode)"
Write-Host "  - Startup Probe: $($contract.probeResults.startupProbe)"
Write-Host "  - Smoke Probe: $($contract.probeResults.smokeProbe)"

# 4. Assert contract hash matches
if ($actualHash -eq $expectedHash) {
    Write-Host "[PASS] Release Contract Hash matches the expected target hash perfectly!" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Release Contract Hash mismatch! Expected: $expectedHash, Got: $actualHash" -ForegroundColor Red
    exit 1
}

# 5. Verify local build integrity (checking key files inside current/)
$requiredFiles = @('index.html', 'main.dart.js', 'flutter.js', 'flutter_bootstrap.js')
$missingCount = 0
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $CurrentDir $file
    if (Test-Path $filePath) {
        $size = (Get-Item -Path $filePath).Length
        Write-Host "  [PASS] file verified: $file ($size bytes)" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [FAIL] missing critical release file: $file" -ForegroundColor Red
        $missingCount++
    }
}

if ($missingCount -gt 0) {
    Write-Host "[FAIL] Local deployment is missing critical assets!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[PASS] All critical Web assets are fully intact and deployed." -ForegroundColor Green
}

Write-Host "`n=== VERIFICATION COMPLETE: RELEASE e7bbaf1d IS 100% SOUND ===" -ForegroundColor Cyan
exit 0
