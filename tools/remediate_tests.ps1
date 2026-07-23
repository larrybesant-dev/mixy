#
# MixVy Flutter Test Remediation Runner
# Version: 1.0
# Purpose: Run integration tests, capture failures, generate error reports for AI patch creation
#

param(
    [string]$TestFile = "integration_test/",
    [int]$MaxAttempts = 5,
    [string]$OutputDir = "."
)

$ErrorActionPreference = "Continue"
$configFile = Join-Path $OutputDir ".remediation_config.json"
$historyFile = Join-Path $OutputDir ".remediation_history.json"
$errorReportFile = Join-Path $OutputDir "error_report.json"
$testLogFile = Join-Path $OutputDir "test_output.log"

# Initialize config if missing
if (-not (Test-Path $configFile)) {
    $defaultConfig = @{
        testPaths           = @("integration_test/")
        maxRetryAttempts    = 5
        excludePatterns     = @("test_helpers.dart", "*.g.dart")
        reportOutputDir     = "."
        consecutiveFailures = 0
    }
    $defaultConfig | ConvertTo-Json | Out-File $configFile -Encoding UTF8
}

# Initialize history if missing
if (-not (Test-Path $historyFile)) {
    @{ attempts = @() } | ConvertTo-Json | Out-File $historyFile -Encoding UTF8
}

$config = Get-Content $configFile | ConvertFrom-Json
$history = Get-Content $historyFile | ConvertFrom-Json

if ($null -eq $history.attempts) {
    $history.attempts = @()
}

# Utility: Display section header
function Write-Section {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor $Color
    Write-Host "  $Title" -ForegroundColor $Color
    Write-Host "========================================================================" -ForegroundColor $Color
    Write-Host ""
}

# Utility: Display step message
function Write-Step {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] >> $Message" -ForegroundColor $Color
}

# Extract code context from file around a line number
function Extract-CodeContext {
    param(
        [string]$FilePath,
        [int]$LineNumber,
        [int]$ContextLines = 5
    )
    
    if (-not (Test-Path $FilePath)) {
        return "File not found: $FilePath"
    }
    
    $content = @(Get-Content $FilePath -ErrorAction SilentlyContinue)
    $startLine = [Math]::Max(0, $LineNumber - $ContextLines)
    $endLine = [Math]::Min($content.Count - 1, $LineNumber + $ContextLines)
    
    $context = @()
    for ($i = $startLine; $i -le $endLine; $i++) {
        $marker = if ($i -eq ($LineNumber - 1)) { ">>> " } else { "    " }
        $context += "$marker$($i + 1): $($content[$i])"
    }
    
    return ($context -join "`n")
}

# Parse Flutter test machine output
function Parse-FlutterTestOutput {
    param([string]$Output)
    
    $failures = @()
    $lines = $Output -split "`n"
    
    foreach ($line in $lines) {
        if ($line.Trim() -eq "") { continue }
        try {
            $event = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($event -and $event.type -eq "testDone" -and $event.result -eq "failure") {
                $failures += @{
                    testName   = $event.testDescription
                    result     = $event.result
                    error      = $event.error
                    stacktrace = $event.stackTrace
                }
            }
        }
        catch {
            # Skip non-JSON lines
        }
    }
    
    return $failures
}

# Extract file location from stack trace
function Get-TestFileFromFailure {
    param([PSCustomObject]$Failure)
    
    $stackLines = $Failure.stacktrace -split "`n"
    foreach ($line in $stackLines) {
        if ($line -match "file://.*\.dart") {
            $match = [regex]::Match($line, 'file://([^:]+):(\d+)')
            if ($match.Success) {
                return @{
                    path       = $match.Groups[1].Value
                    lineNumber = [int]$match.Groups[2].Value
                }
            }
        }
    }
    
    return $null
}

# Generate error report JSON
function Generate-ErrorReport {
    param(
        [PSCustomObject[]]$Failures,
        [int]$AttemptNumber
    )
    
    $report = @{
        timestamp              = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        attemptNumber          = $AttemptNumber
        totalFailures          = $Failures.Count
        testTarget             = $TestFile
        failures               = @()
        previousAttemptSummary = ""
    }
    
    if ($history.attempts.Count -gt 0) {
        $lastAttempt = $history.attempts[-1]
        $report.previousAttemptSummary = "Last attempt: $($lastAttempt.summary)"
    }
    
    foreach ($failure in $Failures) {
        $fileInfo = Get-TestFileFromFailure $failure
        $codeContext = ""
        
        if ($fileInfo) {
            $codeContext = Extract-CodeContext -FilePath $fileInfo.path -LineNumber $fileInfo.lineNumber
        }
        
        $failureDetail = @{
            testName      = $failure.testName
            error         = $failure.error
            stackTrace    = $failure.stacktrace
            codeContext   = $codeContext
            fileLocation  = if ($fileInfo) { "$($fileInfo.path):$($fileInfo.lineNumber)" } else { "Unknown" }
        }
        
        $report.failures += $failureDetail
    }
    
    return $report
}

# Main remediation cycle
function Invoke-RemediationCycle {
    Write-Section "MixVy Test Remediation Runner" "Magenta"
    
    Write-Step "Configuration: $configFile"
    Write-Step "Test target: $TestFile"
    Write-Step "Max attempts: $MaxAttempts"
    Write-Host ""
    
    $attemptNumber = 1
    $testPassed = $false
    
    while ($attemptNumber -le $MaxAttempts -and -not $testPassed) {
        Write-Section "ATTEMPT $attemptNumber" "Yellow"
        
        Write-Step "Running: flutter test --machine $TestFile" "Cyan"
        Write-Host ""
        
        try {
            $testOutput = & flutter test --machine $TestFile 2>&1 | Tee-Object -FilePath $testLogFile
            $failures = Parse-FlutterTestOutput -Output ($testOutput | Out-String)
            
            if ($failures.Count -eq 0) {
                Write-Section "SUCCESS - ALL TESTS PASSED" "Green"
                $testPassed = $true
                
                $history.attempts += @{
                    attemptNumber = $attemptNumber
                    timestamp     = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                    status        = "PASSED"
                    summary       = "All tests passed"
                    failureCount  = 0
                }
                break
            }
            else {
                Write-Host ""
                Write-Step "FAILURES DETECTED - $($failures.Count) test(s) failed" "Red"
                Write-Host ""
                
                $errorReport = Generate-ErrorReport -Failures $failures -AttemptNumber $attemptNumber
                $errorReport | ConvertTo-Json -Depth 10 | Out-File $errorReportFile -Encoding UTF8
                
                Write-Step "Error report: $errorReportFile" "Yellow"
                Write-Host ""
                
                Write-Host "FAILED TESTS:" -ForegroundColor Red
                foreach ($failure in $failures) {
                    Write-Host "  * $($failure.testName)" -ForegroundColor Red
                }
                Write-Host ""
                
                $history.attempts += @{
                    attemptNumber    = $attemptNumber
                    timestamp        = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                    status           = "FAILED"
                    summary          = "$($failures.Count) test(s) failed"
                    failureCount     = $failures.Count
                    firstFailureTest = $failures[0].testName
                }
                
                if ($attemptNumber -ge $MaxAttempts) {
                    Write-Section "MAX ATTEMPTS REACHED" "Red"
                    Write-Host ""
                    Write-Host "Failed to resolve after $MaxAttempts attempts." -ForegroundColor Red
                    Write-Host ""
                    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
                    Write-Host "  1. Copy error report from: $errorReportFile" -ForegroundColor White
                    Write-Host "  2. Paste into AI chat for patch suggestions" -ForegroundColor White
                    Write-Host "  3. Review and apply patch: git apply remediation.patch" -ForegroundColor White
                    Write-Host "  4. Re-run this script" -ForegroundColor White
                    Write-Host ""
                    
                    Write-Host "ERROR REPORT:" -ForegroundColor Cyan
                    Write-Host "=====================================" -ForegroundColor Gray
                    Get-Content $errorReportFile | Write-Host
                    Write-Host "=====================================" -ForegroundColor Gray
                    Write-Host ""
                    break
                }
                else {
                    Write-Step "Waiting 3 seconds before retry..." "Yellow"
                    Start-Sleep -Seconds 3
                }
            }
        }
        catch {
            Write-Host "ERROR: $($_)" -ForegroundColor Red
            $history.attempts += @{
                attemptNumber = $attemptNumber
                timestamp     = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                status        = "ERROR"
                summary       = $_.Exception.Message
            }
            break
        }
        
        $attemptNumber++
    }
    
    # Save history and config
    $config.consecutiveFailures = if ($testPassed) { 0 } else { $history.attempts.Count }
    $config.lastRunTimestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $config | ConvertTo-Json | Out-File $configFile -Encoding UTF8
    
    $history | ConvertTo-Json -Depth 10 | Out-File $historyFile -Encoding UTF8
    
    Write-Section "REMEDIATION SESSION COMPLETE" "Magenta"
    Write-Host "Attempts: $($history.attempts.Count)" -ForegroundColor White
    Write-Host "History: $historyFile" -ForegroundColor Gray
    Write-Host ""
}

# Execute
Invoke-RemediationCycle
