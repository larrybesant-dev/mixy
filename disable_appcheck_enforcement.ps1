#!/usr/bin/env powershell
<#
.SYNOPSIS
Disable App Check enforcement for a Firebase project via REST API.

.DESCRIPTION
This script disables App Check enforcement to allow unvalidated Firestore requests
during the soft-launch phase when reCAPTCHA domain configuration is incomplete.

.PARAMETER ProjectId
The Firebase project ID (e.g., mixvy-v2)

.EXAMPLE
.\disable_appcheck_enforcement.ps1 -ProjectId mixvy-v2
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$ProjectId
)

Write-Host "[AppCheck] Disabling App Check enforcement for project: $ProjectId" -ForegroundColor Yellow

# The Firebase App Check management API requires OAuth2 authentication
# We can use `gcloud auth print-access-token` to get a valid token

try {
  Write-Host "[AppCheck] Getting OAuth2 access token from gcloud..." -ForegroundColor Gray
  $accessToken = & gcloud auth print-access-token 2>$null
  
  if (-not $accessToken) {
    Write-Host "[AppCheck] ERROR: Could not get access token. Make sure you're logged in." -ForegroundColor Red
    Write-Host "[AppCheck] Run: gcloud auth login" -ForegroundColor Yellow
    exit 1
  }

  Write-Host "[AppCheck] Got access token (${($accessToken | Measure-Object -Character).Characters} chars)" -ForegroundColor Green

  # Now we need to get the list of apps in the project to get the app ID
  Write-Host "[AppCheck] Fetching apps for project..." -ForegroundColor Gray
  
  $appsUrl = "https://firebase.googleapis.com/v1/projects/$ProjectId/apps"
  try {
    $appsResponse = Invoke-WebRequest -Uri $appsUrl `
      -Headers @{ "Authorization" = "Bearer $accessToken" } `
      -ErrorAction Stop | ConvertFrom-Json
  } catch {
    Write-Host "[AppCheck] ERROR: Could not fetch apps from Firebase API" -ForegroundColor Red
    Write-Host "[AppCheck] URL: $appsUrl" -ForegroundColor Red
    Write-Host "[AppCheck] Error: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }

  if ($appsResponse.apps.Count -eq 0) {
    Write-Host "[AppCheck] ERROR: No apps found in project" -ForegroundColor Red
    exit 1
  }

  Write-Host "[AppCheck] Found $($appsResponse.apps.Count) app(s)" -ForegroundColor Green
  
  # Filter for web apps
  $webApps = $appsResponse.apps | Where-Object { $_.appPlatform -eq "WEB" }
  
  if ($webApps.Count -eq 0) {
    Write-Host "[AppCheck] ERROR: No WEB apps found in project" -ForegroundColor Red
    exit 1
  }

  Write-Host "[AppCheck] Found $($webApps.Count) web app(s)" -ForegroundColor Green

  # Disable App Check for each web app
  foreach ($app in $webApps) {
    $appId = $app.appId
    $displayName = $app.displayName
    
    Write-Host "[AppCheck] Processing app: $displayName (ID: $appId)" -ForegroundColor Cyan
    
    # Endpoint to get the current App Check config
    $appCheckUrl = "https://firebaseappcheck.googleapis.com/v1beta1/projects/$ProjectId/apps/$appId/appCheckConfig"
    
    Write-Host "[AppCheck] Fetching current App Check config..." -ForegroundColor Gray
    try {
      $currentConfig = Invoke-WebRequest -Uri $appCheckUrl `
        -Headers @{ "Authorization" = "Bearer $accessToken" } `
        -ErrorAction Stop | ConvertFrom-Json
      
      Write-Host "[AppCheck] Current enforcement mode: $($currentConfig.enforcementMode)" -ForegroundColor Cyan
    } catch {
      Write-Host "[AppCheck] Note: Could not fetch current config (may not be configured yet)" -ForegroundColor Yellow
    }

    # Disable enforcement
    Write-Host "[AppCheck] Disabling enforcement (setting to UNENFORCED)..." -ForegroundColor Gray
    
    $body = @{
      enforcementMode = "UNENFORCED"
    } | ConvertTo-Json
    
    try {
      $response = Invoke-WebRequest -Uri $appCheckUrl `
        -Method PATCH `
        -Headers @{
          "Authorization" = "Bearer $accessToken"
          "Content-Type" = "application/json"
        } `
        -Body $body `
        -ErrorAction Stop
      
      Write-Host "[AppCheck] SUCCESS: App Check enforcement disabled!" -ForegroundColor Green
      Write-Host "[AppCheck] Response: $($response.Content)" -ForegroundColor Gray
    } catch {
      Write-Host "[AppCheck] ERROR: Failed to disable enforcement" -ForegroundColor Red
      Write-Host "[AppCheck] Error details: $($_.Exception.Message)" -ForegroundColor Red
      exit 1
    }
  }

  Write-Host "[AppCheck] ========================================" -ForegroundColor Green
  Write-Host "[AppCheck] App Check enforcement disabled!" -ForegroundColor Green
  Write-Host "[AppCheck] Firestore will now accept requests without App Check tokens" -ForegroundColor Green
  Write-Host "[AppCheck] Re-deploy your web app or hard refresh browser (Ctrl+Shift+R)" -ForegroundColor Green
  Write-Host "[AppCheck] ========================================" -ForegroundColor Green

} catch {
  Write-Host "[AppCheck] ERROR: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
