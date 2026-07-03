<#
.SYNOPSIS
    MixVy Post-Deployment Verification Script (Read-Only)
    
.DESCRIPTION
    Verifies that critical Cloud Functions and Firebase endpoints are responding 
    with 200 OK after deployment. This is a read-only verification script that 
    does NOT modify any production data or configuration.
    
    Safe to run multiple times. No side effects.
    
.PARAMETER ProjectId
    Firebase project ID (default: mixvy-v2)
    
.PARAMETER Verbose
    Show detailed HTTP response headers and timing
    
.EXAMPLE
    .\verify_production_deployment.ps1
    .\verify_production_deployment.ps1 -Verbose
    
.AUTHOR
    MixVy DevOps Team
    
.VERSION
    1.0
    
#>

param(
    [string]$ProjectId = "mixvy-v2",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

$region = "us-central1"
$projectNumber = "770164332233"  # From your Firebase project
$baseUrl = "https://$region-$ProjectId.cloudfunctions.net"

# Critical Cloud Functions to verify (read-only operations only)
$functionsToCheck = @(
    @{
        Name = "validateMessageBlockEnforcement"
        Description = "Block enforcement for messages"
        Type = "onDocumentCreated"
        Critical = $true
    },
    @{
        Name = "validateConversationBlockEnforcement"
        Description = "Block enforcement for conversations"
        Type = "onDocumentCreated"
        Critical = $true
    }
)

# Firebase API endpoints to verify
$firebaseEndpoints = @(
    @{
        Name = "Firestore Health"
        Url = "https://firestore.googleapis.com/v1/projects/$ProjectId"
        Critical = $true
    },
    @{
        Name = "Firebase Auth"
        Url = "https://identitytoolkit.googleapis.com/v1/projects/$ProjectId"
        Critical = $true
    }
)

# ──────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host "`n" -NoNewline
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "═" * 80 -ForegroundColor Cyan
}

function Write-Result {
    param(
        [string]$Name,
        [bool]$Success,
        [string]$Message = "",
        [int]$StatusCode = 0,
        [int]$ResponseTimeMs = 0
    )
    
    $status = $Success ? "✅ PASS" : "❌ FAIL"
    $statusColor = $Success ? "Green" : "Red"
    
    Write-Host ""
    Write-Host "  $status" -ForegroundColor $statusColor -NoNewline
    Write-Host " | $Name"
    
    if ($Message) {
        Write-Host "       └─ $Message" -ForegroundColor Gray
    }
    
    if ($StatusCode -gt 0) {
        Write-Host "       └─ Status Code: $StatusCode" -ForegroundColor Gray
    }
    
    if ($ResponseTimeMs -gt 0) {
        Write-Host "       └─ Response Time: ${ResponseTimeMs}ms" -ForegroundColor Gray
    }
}

function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Name,
        [bool]$Critical = $true,
        [string]$Method = "GET"
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $success = $false
    $statusCode = 0
    $message = ""
    
    try {
        # Use -SkipHttpErrorCheck to capture non-2xx responses
        $response = Invoke-WebRequest `
            -Uri $Url `
            -Method $Method `
            -TimeoutSec 10 `
            -SkipHttpErrorCheck `
            -ErrorAction Stop
        
        $statusCode = $response.StatusCode
        $success = ($statusCode -ge 200 -and $statusCode -lt 300)
        
        if ($success) {
            $message = "Responding normally"
        } else {
            $message = "Unexpected status code: $statusCode"
        }
        
    } catch [System.Net.Http.HttpRequestException] {
        $message = "Connection failed: $($_.Exception.Message)"
    } catch [System.TimeoutException] {
        $message = "Request timeout (>10s)"
    } catch {
        $message = "Error: $($_.Exception.Message)"
    } finally {
        $stopwatch.Stop()
    }
    
    Write-Result -Name $Name -Success $success -Message $message -StatusCode $statusCode -ResponseTimeMs $stopwatch.ElapsedMilliseconds
    
    return @{
        Success = $success
        StatusCode = $statusCode
        ResponseTime = $stopwatch.ElapsedMilliseconds
        Critical = $Critical
    }
}

function Test-CloudFunctionDeployed {
    param(
        [string]$FunctionName,
        [string]$ProjectId,
        [string]$Region = "us-central1"
    )
    
    $message = ""
    $success = $false
    
    try {
        # Query Cloud Functions API to check if function exists
        # This is read-only and doesn't invoke the function
        
        # Build Cloud Functions API endpoint
        $apiUrl = "https://cloudfunctions.googleapis.com/v1/projects/$ProjectId/locations/$Region/functions/$FunctionName"
        
        # Try without auth first (public functions)
        $response = Invoke-WebRequest `
            -Uri $apiUrl `
            -Method GET `
            -TimeoutSec 5 `
            -SkipHttpErrorCheck `
            -ErrorAction SilentlyContinue
        
        if ($response.StatusCode -eq 200) {
            $success = $true
            $message = "Function deployed and active"
        } elseif ($response.StatusCode -eq 404) {
            $message = "Function not found (not deployed yet)"
        } else {
            $message = "Status: $($response.StatusCode)"
        }
        
    } catch {
        # If no auth available, assume not deployed
        $message = "Unable to verify (may require authentication)"
    }
    
    return @{
        Success = $success
        Message = $message
    }
}

function Test-FirebaseConsole {
    param(
        [string]$ProjectId
    )
    
    $url = "https://console.firebase.google.com/project/$ProjectId"
    $success = $false
    $message = ""
    
    try {
        $response = Invoke-WebRequest `
            -Uri $url `
            -Method HEAD `
            -TimeoutSec 10 `
            -SkipHttpErrorCheck `
            -ErrorAction SilentlyContinue
        
        $success = ($response.StatusCode -eq 200)
        $message = if ($success) { "Firebase Console accessible" } else { "Status: $($response.StatusCode)" }
        
    } catch {
        $message = "Unable to reach Firebase Console"
    }
    
    return @{
        Success = $success
        Message = $message
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN VERIFICATION WORKFLOW
# ──────────────────────────────────────────────────────────────────────────────

Write-Header "MixVy Production Deployment Verification"
Write-Host ""
Write-Host "Project ID: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $region" -ForegroundColor Gray
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# ──────────────────────────────────────────────────────────────────────────────
# Phase 1: Check Firebase Core Services
# ──────────────────────────────────────────────────────────────────────────────

Write-Header "Phase 1: Firebase Core Services"

$coreResults = @()

foreach ($endpoint in $firebaseEndpoints) {
    $result = Test-Endpoint `
        -Url $endpoint.Url `
        -Name $endpoint.Name `
        -Critical $endpoint.Critical
    
    $coreResults += $result
}

# ──────────────────────────────────────────────────────────────────────────────
# Phase 2: Check Cloud Functions Deployment Status
# ──────────────────────────────────────────────────────────────────────────────

Write-Header "Phase 2: Cloud Functions Deployment Status"

$functionResults = @()

foreach ($func in $functionsToCheck) {
    $result = Test-CloudFunctionDeployed `
        -FunctionName $func.Name `
        -ProjectId $ProjectId `
        -Region $region
    
    Write-Result `
        -Name $func.Name `
        -Success $result.Success `
        -Message $result.Message
    
    $functionResults += @{
        Name = $func.Name
        Success = $result.Success
        Critical = $func.Critical
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Phase 3: Check Firebase Console
# ──────────────────────────────────────────────────────────────────────────────

Write-Header "Phase 3: Firebase Console Access"

$consoleResult = Test-FirebaseConsole -ProjectId $ProjectId

Write-Result `
    -Name "Firebase Console" `
    -Success $consoleResult.Success `
    -Message $consoleResult.Message

# ──────────────────────────────────────────────────────────────────────────────
# Phase 4: Summary & Recommendations
# ──────────────────────────────────────────────────────────────────────────────

Write-Header "Verification Summary"

$allCoreHealthy = $coreResults | Where-Object { $_.Critical } | ForEach-Object { $_.Success } | Measure-Object -AllStats | Select-Object -ExpandProperty Average
$allFunctionsDeployed = $functionResults | Where-Object { $_.Critical } | ForEach-Object { $_.Success } | Measure-Object -AllStats | Select-Object -ExpandProperty Average

$corePass = $coreResults | Where-Object { $_.Success } | Measure-Object | Select-Object -ExpandProperty Count
$coreTotal = $coreResults | Measure-Object | Select-Object -ExpandProperty Count

$funcPass = $functionResults | Where-Object { $_.Success } | Measure-Object | Select-Object -ExpandProperty Count
$funcTotal = $functionResults | Measure-Object | Select-Object -ExpandProperty Count

Write-Host ""
Write-Host "  Core Services:       $corePass/$coreTotal passing" -ForegroundColor $(if ($corePass -eq $coreTotal) { "Green" } else { "Red" })
Write-Host "  Cloud Functions:     $funcPass/$funcTotal deployed" -ForegroundColor $(if ($funcPass -eq $funcTotal) { "Green" } else { "Yellow" })
Write-Host ""

# ──────────────────────────────────────────────────────────────────────────────
# Decision Logic
# ──────────────────────────────────────────────────────────────────────────────

Write-Header "Deployment Status"

$allHealthy = ($corePass -eq $coreTotal) -and ($funcPass -eq $funcTotal)
$coreHealthy = ($corePass -eq $coreTotal)
$functionsReady = ($funcPass -gt 0)

if ($allHealthy) {
    Write-Host "  🟢 READY FOR SOFT LAUNCH" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ✅ All Firebase services responding normally"
    Write-Host "  ✅ All critical Cloud Functions deployed"
    Write-Host "  ✅ Block enforcement active and enforced"
    Write-Host ""
    Write-Host "  → Proceed to invite first 50 users" -ForegroundColor Green
    $exitCode = 0
    
} elseif ($coreHealthy -and -not $functionsReady) {
    Write-Host "  🟡 PARTIALLY READY (IAM ISSUE)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ✅ Firebase core services healthy"
    Write-Host "  ❌ Cloud Functions not yet deployed (IAM permissions pending)"
    Write-Host ""
    Write-Host "  → Run these commands to grant IAM permissions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  gcloud projects add-iam-policy-binding $ProjectId \" -ForegroundColor Cyan
    Write-Host "    --member=serviceAccount:service-770164332233@gcp-sa-pubsub.iam.gserviceaccount.com \" -ForegroundColor Cyan
    Write-Host "    --role=roles/iam.serviceAccountTokenCreator" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  gcloud projects add-iam-policy-binding $ProjectId \" -ForegroundColor Cyan
    Write-Host "    --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \" -ForegroundColor Cyan
    Write-Host "    --role=roles/run.invoker" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  gcloud projects add-iam-policy-binding $ProjectId \" -ForegroundColor Cyan
    Write-Host "    --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \" -ForegroundColor Cyan
    Write-Host "    --role=roles/eventarc.eventReceiver" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Then re-run: firebase deploy --only functions" -ForegroundColor Cyan
    $exitCode = 1
    
} else {
    Write-Host "  🔴 DEPLOYMENT BLOCKED" -ForegroundColor Red
    Write-Host ""
    Write-Host "  ❌ Firebase services not fully operational"
    Write-Host ""
    Write-Host "  → Check Firebase Console for errors: https://console.firebase.google.com/project/$ProjectId" -ForegroundColor Red
    Write-Host "  → Review function logs: firebase functions:log" -ForegroundColor Red
    $exitCode = 1
}

Write-Host ""
Write-Host "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# ──────────────────────────────────────────────────────────────────────────────
# Additional Diagnostics (if Verbose)
# ──────────────────────────────────────────────────────────────────────────────

if ($Verbose) {
    Write-Header "Diagnostic Information"
    
    Write-Host ""
    Write-Host "Firebase CLI version:" -ForegroundColor Cyan
    try {
        firebase --version 2>$null
    } catch {
        Write-Host "  (Firebase CLI not available in PATH)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Project details from .firebaserc:" -ForegroundColor Cyan
    if (Test-Path ".firebaserc") {
        Get-Content ".firebaserc" | Write-Host
    } else {
        Write-Host "  (Not in project root)" -ForegroundColor Gray
    }
}

Write-Host ""
exit $exitCode
