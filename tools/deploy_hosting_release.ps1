<#
.SYNOPSIS
    Canonical Mixvy Firebase Hosting release script.

.DESCRIPTION
    Reads firebase.json hosting.public and runs the matching build pipeline
    before deploying. This avoids path drift between Flutter build/web and
    AI web apps/mixvy_ai_web/dist workflows.
#>

param(
    [string]$ProjectId = "mixvy-v2",
    [switch]$SkipLint,
    [switch]$SkipBuild,
    [switch]$SkipVerify,
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

function Write-Stage {
    param([string]$Name)
    Write-Host ""
    Write-Host "== $Name ==" -ForegroundColor Cyan
}

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Invoke-Checked {
    param(
        [string]$Command,
        [string]$FailureMessage
    )

    Write-Host "> $Command" -ForegroundColor DarkGray
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Assert-Command firebase

$firebaseConfigPath = Join-Path $repoRoot "firebase.json"
if (-not (Test-Path $firebaseConfigPath)) {
    throw "firebase.json not found at repository root."
}

$firebaseConfig = Get-Content -Path $firebaseConfigPath -Raw | ConvertFrom-Json
if (-not $firebaseConfig.hosting -or -not $firebaseConfig.hosting.public) {
    throw "firebase.json is missing hosting.public"
}

$hostingPublic = [string]$firebaseConfig.hosting.public
Write-Host "Hosting public path: $hostingPublic" -ForegroundColor Yellow

if (-not $SkipBuild) {
    switch ($hostingPublic) {
        "apps/mixvy_ai_web/dist" {
            $packagePath = Join-Path $repoRoot "apps/mixvy_ai_web/package.json"
            if (-not (Test-Path $packagePath)) {
                throw "Expected apps/mixvy_ai_web/package.json for AI web build, but it was not found."
            }

            Assert-Command npm

            if (-not $SkipLint) {
                Write-Stage "Lint AI web"
                Invoke-Checked "npm --prefix apps/mixvy_ai_web run lint" "AI web lint failed."
            }

            Write-Stage "Build AI web"
            Invoke-Checked "npm --prefix apps/mixvy_ai_web run build" "AI web build failed."
        }
        "build/web" {
            Assert-Command flutter
            Write-Stage "Build Flutter web"
            Invoke-Checked "flutter build web --release" "Flutter web build failed."
        }
        default {
            Write-Host "No build automation mapped for hosting.public='$hostingPublic'." -ForegroundColor Yellow
            Write-Host "Skipping build and expecting artifacts to already exist." -ForegroundColor Yellow
        }
    }
}

$publicPath = Join-Path $repoRoot $hostingPublic
if (-not (Test-Path $publicPath)) {
    throw "Hosting public directory does not exist: $publicPath"
}

Write-Stage "Deploy Firebase Hosting"
if ($ValidateOnly) {
    Write-Host "Validate-only mode enabled. Skipping Firebase deploy." -ForegroundColor Yellow
} else {
    Invoke-Checked "firebase deploy --only hosting --project $ProjectId" "Firebase Hosting deploy failed."
}

if (-not $SkipVerify -and -not $ValidateOnly) {
    Write-Stage "Verify production auth route"
    $url = "https://$ProjectId.web.app/auth"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    Write-Host "status=$([int]$response.StatusCode)" -ForegroundColor Green
    if ($response.Content -match '<title>(.*?)</title>') {
        Write-Host "title=$($matches[1])" -ForegroundColor Green
    }
}

Write-Host "" 
Write-Host "Deployment workflow completed successfully." -ForegroundColor Green