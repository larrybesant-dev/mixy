$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot

try {
  Write-Host 'Running Firestore contract compiler...' -ForegroundColor Green
  npm run firestore:contract
  if ($LASTEXITCODE -ne 0) {
    exit 1
  }

  $surfacePath = 'artifacts/firestore_write_surface.json'

  Write-Host "Checking for uncommitted write-surface drift at $surfacePath ..." -ForegroundColor Green
  git diff --exit-code -- $surfacePath
  if ($LASTEXITCODE -ne 0) {
    Write-Error 'Uncommitted Firestore write surface drift detected.'
    exit 1
  }

  Write-Host 'Firestore contract CI gate passed.' -ForegroundColor Green
} finally {
  Pop-Location
}