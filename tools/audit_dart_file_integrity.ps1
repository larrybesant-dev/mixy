$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$emptyFiles = Get-ChildItem -Path $root -Recurse -Filter *.dart -File |
  Where-Object { $_.Length -eq 0 } |
  Sort-Object FullName

if ($emptyFiles.Count -eq 0) {
  Write-Host 'OK: no zero-byte Dart files found.'
  exit 0
}

Write-Error (("Zero-byte Dart files found:`n{0}") -f ($emptyFiles.FullName -join "`n"))
exit 1