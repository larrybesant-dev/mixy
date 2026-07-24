$ErrorActionPreference = 'Stop'

function Resolve-JavaCommand {
  $candidates = @()

  if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME 'bin/java'
    if ($IsWindows) {
      $candidate = "$candidate.exe"
    }
    $candidates += $candidate
  }

  $candidates += 'java'

  foreach ($candidate in $candidates) {
    if ($candidate -ne 'java' -and -not (Test-Path $candidate)) {
      continue
    }

    try {
      if ($candidate -eq 'java') {
        $resolved = Get-Command java -ErrorAction Stop
        return $resolved.Source
      }
      return $candidate
    } catch {
      continue
    }
  }

  return $null
}

function Get-JavaMajorVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$JavaCommand
  )

  try {
    # java -version writes to stderr on many distributions.
    # Convert all stream values to plain strings for stable parsing.
    $output = (& $JavaCommand -version 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
  } catch {
    return $null
  }

  if ([string]::IsNullOrWhiteSpace($output)) {
    return $null
  }

  $patterns = @(
    'version\s+"(?<major>\d+)(?:\.\d+)?',
    'openjdk\s+(?<major>\d+)(?:\.\d+)?'
  )

  foreach ($pattern in $patterns) {
    $match = [regex]::Match($output, $pattern)
    if ($match.Success) {
      return [int]$match.Groups['major'].Value
    }
  }

  return $null
}

$javaCommand = Resolve-JavaCommand
if ($null -eq $javaCommand) {
  Write-Error 'Java executable was not found on PATH and JAVA_HOME/bin/java is unavailable. Install Temurin JDK 21+ to run Firestore rules tests.'
  exit 1
}

$javaMajor = Get-JavaMajorVersion -JavaCommand $javaCommand
if ($null -eq $javaMajor) {
  Write-Error "Java is present at '$javaCommand' but version could not be detected. Install Temurin JDK 21+ to run Firestore rules tests."
  exit 1
}

if ($javaMajor -lt 21) {
  Write-Error "Detected Java $javaMajor. Firestore emulator requires Java 21+. Install Temurin JDK 21+ and retry."
  exit 1
}

Write-Host "Java $javaMajor detected at '$javaCommand'. Running Firestore contract coverage gate..." -ForegroundColor Green
node tools/firestore_contract_compiler.mjs

Write-Host "Coverage gate passed. Running Firestore rules tests..." -ForegroundColor Green
npm --prefix functions run test:rules
