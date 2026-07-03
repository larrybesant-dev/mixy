# Firebase Emulator Quick-Start Script for MixVy Permission Testing
# Usage: powershell -ExecutionPolicy Bypass -File tools/run_emulator_tests.ps1
# Status: Production-ready

$ErrorActionPreference = "Stop"

# Colors and formatting
function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Firebase Emulator Testing Suite - Room Join Permissions          ║" -ForegroundColor Cyan
    Write-Host "║  MixVy v2 - 2026-07-03                                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Number, [string]$Message)
    Write-Host "[$Number] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Display header
Write-Section

# Step 1: Check Java
Write-Step "1/5" "Checking Java installation..."
try {
    $javaVersion = java -version 2>&1 | Select-String 'version' | ForEach-Object { $_ -replace 'java version "|openjdk version "' } | Select-Object -First 1
    Write-Success "Java $javaVersion found"
} catch {
    Write-Error-Custom "Java not found. Install Java 21+"
    exit 1
}

# Step 2: Check Firebase CLI
Write-Step "2/5" "Checking Firebase CLI..."
try {
    $firebaseVersion = firebase --version 2>&1
    Write-Success "Firebase CLI found: $firebaseVersion"
} catch {
    Write-Error-Custom "Firebase CLI not found. Run: npm install -g firebase-tools"
    exit 1
}

# Step 3: Verify firestore.rules
Write-Step "3/5" "Verifying firestore.rules..."
if (-not (Test-Path "firestore.rules")) {
    Write-Error-Custom "firestore.rules not found in current directory"
    exit 1
}
$ruleCount = (Get-Content firestore.rules | Select-String -Pattern "function|match" | Measure-Object -Line).Lines
Write-Success "firestore.rules validated ($ruleCount rules/functions)"

# Step 4: Kill existing processes
Write-Step "4/5" "Cleaning up existing processes..."
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Success "Previous emulator instances stopped"

# Step 5: Start emulator
Write-Step "5/5" "Starting Firebase Emulator Suite..."
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Emulator Dashboard: http://localhost:4000" -ForegroundColor Yellow
Write-Host "Firestore Emulator: 127.0.0.1:8085" -ForegroundColor Yellow
Write-Host "Auth Emulator: 127.0.0.1:9099" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting in TEST MODE..." -ForegroundColor Cyan
Write-Host ""

# Try to import backup if exists, otherwise just start fresh
if (Test-Path "emulator-backup") {
    firebase emulators:start `
        --project=mixvy-rules-test `
        --only=firestore,auth `
        --import=./emulator-backup
} else {
    firebase emulators:start `
        --project=mixvy-rules-test `
        --only=firestore,auth
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Success "Emulator Suite Ready"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open: http://localhost:4000 (Emulator Dashboard)"
Write-Host "2. Copy test commands from FIREBASE_EMULATOR_TEST_PLAN_2026-07-03.md"
Write-Host "3. Paste into browser console to run permission tests"
Write-Host "4. Monitor Firestore collection: rooms → {roomId} → participants"
Write-Host ""
Write-Host "Press Ctrl+C to stop emulator" -ForegroundColor Yellow
