# Post-build script for Flutter Web - ensures all assets are properly copied
# This script runs after flutter build web to copy assets that weren't auto-included

param(
    [string]$BuildMode = "release"
)

$BuildDir = "build\web\assets"
$AssetsDir = "assets"
$AssetsSubDirs = @("images", "icons", "fonts", "emojis")

Write-Host "[MIXVY] Post-Build Asset Copy Script"
Write-Host "====================================="
Write-Host "Build Mode: $BuildMode"
Write-Host "Target: $BuildDir"
Write-Host ""

# Check if build directory exists
if (-not (Test-Path $BuildDir)) {
    Write-Error "Build directory not found: $BuildDir"
    exit 1
}

# Copy all asset subdirectories
foreach ($subDir in $AssetsSubDirs) {
    $source = Join-Path $AssetsDir $subDir
    $destination = Join-Path $BuildDir $subDir
    
    if (Test-Path $source) {
        Write-Host "Copying $subDir..."
        
        # Remove old directory if it exists
        if (Test-Path $destination) {
            Remove-Item $destination -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Copy new directory
        Copy-Item $source -Destination $destination -Recurse -Force
        
        $itemCount = (Get-ChildItem $destination -Recurse | Measure-Object).Count
        Write-Host "   [OK] Copied $itemCount items"
    } else {
        Write-Host "   [WARN] Source directory not found: $source"
    }
}

# Verify critical assets
$criticalAssets = @(
    "assets\images\branding\mixvy_logo.png"
)

Write-Host ""
Write-Host "Verifying critical assets..."
foreach ($asset in $criticalAssets) {
    $webPath = Join-Path "build\web" $asset
    if (Test-Path $webPath) {
        Write-Host "   [OK] $asset"
    } else {
        Write-Host "   [ERROR] MISSING: $asset"
    }
}

Write-Host ""
Write-Host "Post-build cleanup complete!"
Write-Host "To use automatically: flutter build web --release && powershell -ExecutionPolicy Bypass -File tools/post_build_web.ps1"
