param(
    [string]$cmd = "help"
)

function Header($title) {
    Write-Host "`n============================" -ForegroundColor Cyan
    Write-Host " $title" -ForegroundColor Cyan
    Write-Host "============================`n" -ForegroundColor Cyan
}

function Run($label, $command) {
    Write-Host "▶ $label" -ForegroundColor Yellow
    Invoke-Expression $command
}

switch ($cmd) {

    "clean" {
        Header "Flutter Clean Build"
        Run "Cleaning project" "flutter clean"
        Run "Getting packages" "flutter pub get"
    }

    "run" {
        Header "Running App (Web)"
        Run "Starting Flutter Web" "flutter run -d chrome"
    }

    "reset" {
        Header "Reset Dev Environment"
        Run "Release common dev ports" "powershell -ExecutionPolicy Bypass -File tools/reset_dev_environment.ps1"
    }

    "build" {
        Header "Production Build"
        Run "Building release" "flutter build web --release"
    }

    "firebase:deploy" {
        Header "Firebase Deploy"
        Run "Deploying Firestore rules" "firebase deploy --only firestore:rules"
        Run "Deploying indexes" "firebase deploy --only firestore:indexes"
        Run "Deploying full backend" "firebase deploy"
    }

    "audit:streams" {
        Header "Stream / Listener Audit"

        Run "Checking snapshots usage" `
        "Get-ChildItem -Recurse -Include *.dart | Select-String 'snapshots\('"

        Run "Checking StreamProviders" `
        "Get-ChildItem -Recurse -Include *.dart | Select-String 'StreamProvider'"

        Run "Checking Firestore listeners" `
        "Get-ChildItem -Recurse -Include *.dart | Select-String '\.listen\('"
    }

    "audit:firebase" {
        Header "Firebase Risk Scan"

        Run "Checking Firestore usage patterns" `
        "Get-ChildItem -Recurse -Include *.dart | Select-String 'Firestore'"

        Run "Checking RTDB usage" `
        "Get-ChildItem -Recurse -Include *.dart | Select-String 'RealtimeDatabase|firebase_database'"
    }

    "verify" {
        Header "Pre-Launch Verification"

        Run "Clean build check" "flutter clean"
        Run "Get dependencies" "flutter pub get"

        Write-Host "`n✔ Manual checks required:" -ForegroundColor Green
        Write-Host "- No boot errors"
        Write-Host "- No duplicate listeners"
        Write-Host "- Presence stable"
        Write-Host "- Typing stable"
        Write-Host "- MessageModels stable"
    }

    "launch" {
        Header "FULL LAUNCH PIPELINE"

        Run "Clean" "flutter clean"
        Run "Get packages" "flutter pub get"

        Run "Audit streams" "Get-ChildItem -Recurse -Include *.dart | Select-String 'snapshots\('"
        Run "Audit providers" "Get-ChildItem -Recurse -Include *.dart | Select-String 'StreamProvider'"

        Run "Build release" "flutter build web --release"

        Write-Host "`n✔ Build complete" -ForegroundColor Green
        Write-Host "Next step: firebase deploy (manual or run dev.ps1 firebase:deploy)"
    }

    default {
        Write-Host "Commands:"
        Write-Host "  .\dev.ps1 clean"
        Write-Host "  .\dev.ps1 run"
        Write-Host "  .\dev.ps1 reset"
        Write-Host "  .\dev.ps1 build"
        Write-Host "  .\dev.ps1 firebase:deploy"
        Write-Host "  .\dev.ps1 audit:streams"
        Write-Host "  .\dev.ps1 audit:firebase"
        Write-Host "  .\dev.ps1 verify"
        Write-Host "  .\dev.ps1 launch"
    }
}
