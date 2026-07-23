param(
  [int]$Port = 8080,
  [string]$StartupProbeReportPath = 'tools/reports/startup_probe_report.json',
  [string]$SmokeProbeReportPath = 'tools/reports/web_failure_smoke_report.json',
  [string]$PreflightContractPath = 'artifacts/preflight_contract.json',
  [string]$PreviousHashPath = 'artifacts/hash_chain/previous_contract_hash.txt',
  [string]$ContractPath = 'artifacts/deployment_contract.json',
  [string]$SchemaPath = 'tools/deployment_contract.schema.json',
  [string]$EvaluationOutputPath = 'artifacts/deployment_contract_evaluation.json',
  [string]$ResolvedContractPath = 'artifacts/deployment_contract.resolved.json',
  [string]$CurrentHashPath = 'artifacts/hash_chain/current_contract_hash.txt'
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# DETERMINISM VERIFICATION TEST
# ============================================================================
# Runs build and evaluate steps twice to verify bit-for-bit reproducibility
# Fails if any output differs between runs
# ============================================================================

Write-Host "================================================"
Write-Host "DETERMINISM VERIFICATION TEST"
Write-Host "================================================"
Write-Host ""
Write-Host "Testing determinism with inputs:"
Write-Host "  - Port: $Port"
Write-Host "  - Startup Report: $StartupProbeReportPath"
Write-Host "  - Smoke Report: $SmokeProbeReportPath"
Write-Host "  - Preflight Contract: $PreflightContractPath"
Write-Host "  - Previous Hash: $PreviousHashPath"
Write-Host ""

# Ensure artifacts directory exists
New-Item -ItemType Directory -Path 'artifacts/determinism_test' -Force | Out-Null

$testResultPath = 'artifacts/determinism_test/verification_result.json'
$run1ContractPath = 'artifacts/determinism_test/run1_contract.json'
$run1ResolvedPath = 'artifacts/determinism_test/run1_resolved.json'
$run1EvalPath = 'artifacts/determinism_test/run1_evaluation.json'
$run1HashPath = 'artifacts/determinism_test/run1_current_hash.txt'

$run2ContractPath = 'artifacts/determinism_test/run2_contract.json'
$run2ResolvedPath = 'artifacts/determinism_test/run2_resolved.json'
$run2EvalPath = 'artifacts/determinism_test/run2_evaluation.json'
$run2HashPath = 'artifacts/determinism_test/run2_current_hash.txt'

$testResult = [ordered]@{
  testName = 'contract_determinism'
  runs = @(
    @{ run = 1; contractHash = $null; resolvedHash = $null; evaluationHash = $null; status = 'pending' },
    @{ run = 2; contractHash = $null; resolvedHash = $null; evaluationHash = $null; status = 'pending' }
  )
  deterministic = $null
  failures = @()
}

function Get-FileHash {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    return $null
  }
  $content = Get-Content -Path $Path -Raw
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
}

function Invoke-BuildAndEvaluation {
  param(
    [int]$RunNumber,
    [string]$WorkContractPath,
    [string]$WorkResolvedPath,
    [string]$WorkEvalPath,
    [string]$WorkHashPath
  )

  Write-Host ""
  Write-Host "--- RUN ${RunNumber}: Building Contract ---"

  Remove-Item -Path $WorkContractPath -ErrorAction SilentlyContinue
  Remove-Item -Path $WorkResolvedPath -ErrorAction SilentlyContinue
  Remove-Item -Path $WorkEvalPath -ErrorAction SilentlyContinue
  Remove-Item -Path $WorkHashPath -ErrorAction SilentlyContinue
  
  try {
    & powershell -ExecutionPolicy Bypass -File tools/build_deployment_contract.ps1 `
      -Port $Port `
      -StartupProbeReportPath $StartupProbeReportPath `
      -SmokeProbeReportPath $SmokeProbeReportPath `
      -PreflightContractPath $PreflightContractPath `
      -PreviousHashPath $PreviousHashPath `
      -OutputPath $WorkContractPath
    
    if ($LASTEXITCODE -ne 0) {
      Write-Host "WARN: Build exited with code $LASTEXITCODE (expected for some states)"
    }
  }
  catch {
    Write-Host "ERROR: Build failed: $_"
    $testResult.failures += "Run $RunNumber build error: $_"
    return $false
  }

  if (-not (Test-Path $WorkContractPath)) {
    Write-Host "ERROR: Contract not created"
    $testResult.failures += "Run ${RunNumber}: contract file not created"
    return $false
  }

  Write-Host "OK: Contract generated"

  Write-Host "--- RUN ${RunNumber}: Evaluating Contract ---"
  
  try {
    & powershell -ExecutionPolicy Bypass -File tools/evaluate_deployment_contract.ps1 `
      -ContractPath $WorkContractPath `
      -SchemaPath $SchemaPath `
      -OutputPath $WorkEvalPath `
      -ResolvedContractPath $WorkResolvedPath `
      -CurrentHashPath $WorkHashPath
    
    if ($LASTEXITCODE -ne 0) {
      Write-Host "WARN: Evaluation exited with code $LASTEXITCODE (expected for deny decisions)"
    }
  }
  catch {
    Write-Host "ERROR: Evaluation failed: $_"
    $testResult.failures += "Run $RunNumber evaluation error: $_"
    return $false
  }

  if (-not (Test-Path $WorkResolvedPath)) {
    Write-Host "ERROR: Resolved contract not created"
    $testResult.failures += "Run ${RunNumber}: resolved contract file not created"
    return $false
  }

  Write-Host "OK: Contract evaluated"

  $contractHash = Get-FileHash $WorkContractPath
  $resolvedHash = Get-FileHash $WorkResolvedPath
  $evalHash = Get-FileHash $WorkEvalPath

  Write-Host "  Contract Hash:   $contractHash"
  Write-Host "  Resolved Hash:   $resolvedHash"
  Write-Host "  Evaluation Hash: $evalHash"

  return @{
    contractHash = $contractHash
    resolvedHash = $resolvedHash
    evaluationHash = $evalHash
  }
}

# Execute RUN 1
Write-Host ""
Write-Host "========== RUN 1 =========="
$run1Results = Invoke-BuildAndEvaluation -RunNumber 1 `
  -WorkContractPath $run1ContractPath `
  -WorkResolvedPath $run1ResolvedPath `
  -WorkEvalPath $run1EvalPath `
  -WorkHashPath $run1HashPath

if ($run1Results -is [bool] -and -not $run1Results) {
  $testResult.runs[0].status = 'failed'
  $testResult.deterministic = $false
  $testResultJson = $testResult | ConvertTo-Json -Depth 10
  Write-Host ""
  Write-Host "ERROR: DETERMINISM TEST FAILED (Run 1 error)"
  Write-Host $testResultJson
  exit 1
}

$testResult.runs[0].contractHash = $run1Results.contractHash
$testResult.runs[0].resolvedHash = $run1Results.resolvedHash
$testResult.runs[0].evaluationHash = $run1Results.evaluationHash
$testResult.runs[0].status = 'completed'

# Execute RUN 2
Write-Host ""
Write-Host "========== RUN 2 =========="
$run2Results = Invoke-BuildAndEvaluation -RunNumber 2 `
  -WorkContractPath $run2ContractPath `
  -WorkResolvedPath $run2ResolvedPath `
  -WorkEvalPath $run2EvalPath `
  -WorkHashPath $run2HashPath

if ($run2Results -is [bool] -and -not $run2Results) {
  $testResult.runs[1].status = 'failed'
  $testResult.deterministic = $false
  $testResultJson = $testResult | ConvertTo-Json -Depth 10
  Write-Host ""
  Write-Host "ERROR: DETERMINISM TEST FAILED (Run 2 error)"
  Write-Host $testResultJson
  exit 1
}

$testResult.runs[1].contractHash = $run2Results.contractHash
$testResult.runs[1].resolvedHash = $run2Results.resolvedHash
$testResult.runs[1].evaluationHash = $run2Results.evaluationHash
$testResult.runs[1].status = 'completed'

# COMPARISON PHASE
Write-Host ""
Write-Host "========== DETERMINISM COMPARISON =========="
Write-Host ""

$allMatch = $true

# Compare contract hashes
if ($run1Results.contractHash -eq $run2Results.contractHash) {
  Write-Host "OK: Contract hashes match: $($run1Results.contractHash)"
}
else {
  Write-Host "ERROR: Contract hashes differ"
  Write-Host "   Run 1: $($run1Results.contractHash)"
  Write-Host "   Run 2: $($run2Results.contractHash)"
  $testResult.failures += "Contract hash mismatch between runs"
  $allMatch = $false
}

# Compare resolved contract hashes
if ($run1Results.resolvedHash -eq $run2Results.resolvedHash) {
  Write-Host "OK: Resolved contract hashes match: $($run1Results.resolvedHash)"
}
else {
  Write-Host "ERROR: Resolved contract hashes differ"
  Write-Host "   Run 1: $($run1Results.resolvedHash)"
  Write-Host "   Run 2: $($run2Results.resolvedHash)"
  $testResult.failures += "Resolved contract hash mismatch between runs"
  $allMatch = $false
}

# Compare evaluation hashes
if ($run1Results.evaluationHash -eq $run2Results.evaluationHash) {
  Write-Host "OK: Evaluation output hashes match: $($run1Results.evaluationHash)"
}
else {
  Write-Host "ERROR: Evaluation output hashes differ"
  Write-Host "   Run 1: $($run1Results.evaluationHash)"
  Write-Host "   Run 2: $($run2Results.evaluationHash)"
  $testResult.failures += "Evaluation output hash mismatch between runs"
  $allMatch = $false
}

# Detailed content comparison for debugging
if (-not $allMatch) {
  Write-Host ""
  Write-Host "========== DETAILED COMPARISON =========="
  
  if ($run1Results.resolvedHash -ne $run2Results.resolvedHash) {
    Write-Host ""
    Write-Host "Resolved contract content comparison:"
    
    $run1Content = Get-Content -Path $run1ResolvedPath -Raw
    $run2Content = Get-Content -Path $run2ResolvedPath -Raw
    
    try {
      $run1Json = $run1Content | ConvertFrom-Json
      $run2Json = $run2Content | ConvertFrom-Json
      
      Write-Host "Run 1 state: $($run1Json.contractState), decision: $($run1Json.governance.decision), reason: $($run1Json.governance.reasonCode)"
      Write-Host "Run 2 state: $($run2Json.contractState), decision: $($run2Json.governance.decision), reason: $($run2Json.governance.reasonCode)"
      
      if ($run1Json.contractHash -ne $run2Json.contractHash) {
        Write-Host ""
        Write-Host "Contract hash field differs:"
        Write-Host "  Run 1: $($run1Json.contractHash)"
        Write-Host "  Run 2: $($run2Json.contractHash)"
      }
    }
    catch {
      Write-Host "Could not parse JSON for comparison: $_"
    }
  }
}

$testResult.deterministic = $allMatch

# Write test result
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$testResultJson = $testResult | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($testResultPath, $testResultJson, $utf8NoBom)

Write-Host ""
Write-Host "================================================"
if ($allMatch) {
  Write-Host "PASS: DETERMINISM VERIFIED"
  Write-Host "================================================"
  Write-Host ""
  Write-Host "All contract generation and evaluation outputs are deterministic."
  Write-Host "System is ready for release governance."
  Write-Host ""
  exit 0
}
else {
  Write-Host "FAIL: DETERMINISM VIOLATIONS DETECTED"
  Write-Host "================================================"
  Write-Host ""
  Write-Host "Failures:"
  $testResult.failures | ForEach-Object {
    Write-Host "  - $_"
  }
  Write-Host ""
  Write-Host "Test result saved to: $testResultPath"
  Write-Host ""
  exit 1
}
