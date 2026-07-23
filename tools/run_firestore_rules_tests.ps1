$ErrorActionPreference = 'Stop'

function Get-JavaMajorVersion {
  try {
    # java -version writes to stderr on many distributions.
    # Merge stderr into stdout so parsing works cross-platform.
    $output = (& java -version 2>&1 | Out-String)
  } catch {
    return $null
  }

  if (-not $output) {
    return $null
  }

  $match = [regex]::Match($output, 'version\s+"(?<major>\d+)(\.\d+)?')
  if (-not $match.Success) {
    return $null
  }

  return [int]$match.Groups['major'].Value
}

$javaMajor = Get-JavaMajorVersion
if ($null -eq $javaMajor) {
  Write-Error 'Java is not installed or version could not be detected. Install Temurin JDK 21+ to run Firestore rules tests.'
  exit 1
}

if ($javaMajor -lt 21) {
  Write-Error "Detected Java $javaMajor. Firestore emulator requires Java 21+. Install Temurin JDK 21+ and retry."
  exit 1
}

Write-Host "Java $javaMajor detected. Running Firestore contract coverage gate..." -ForegroundColor Green
node tools/firestore_contract_compiler.mjs

Write-Host "Coverage gate passed. Running Firestore rules tests..." -ForegroundColor Green
npm --prefix functions run test:rules
