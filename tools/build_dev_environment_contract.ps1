param(
  [string]$OutputPath = 'artifacts/dev_environment_contract.json',
  [string]$SettingsPath = '.vscode/settings.json',
  [string]$RunId = ''
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )

  New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force | Out-Null
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Convert-ToCanonicalData {
  param($Value)

  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $ordered = [ordered]@{}
    foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
      $ordered[$key] = Convert-ToCanonicalData -Value $Value[$key]
    }
    return $ordered
  }

  if ($Value -is [System.Management.Automation.PSCustomObject]) {
    $ordered = [ordered]@{}
    foreach ($key in @($Value.PSObject.Properties.Name | Sort-Object)) {
      $ordered[$key] = Convert-ToCanonicalData -Value $Value.$key
    }
    return $ordered
  }

  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $items = @()
    foreach ($item in $Value) {
      $items += ,(Convert-ToCanonicalData -Value $item)
    }
    return $items
  }

  return $Value
}

function Convert-ToCanonicalJson {
  param($Value)

  return ((Convert-ToCanonicalData -Value $Value) | ConvertTo-Json -Depth 50 -Compress)
}

function Get-Sha256Hex {
  param([string]$InputText)

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
  $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
}

function Get-OsClass {
  if ($env:RUNNER_OS) {
    switch ($env:RUNNER_OS.ToLowerInvariant()) {
      'windows' { return 'windows' }
      'linux' { return 'linux' }
      'macos' { return 'macos' }
    }
  }

  if ($IsWindows) { return 'windows' }
  if ($IsLinux) { return 'linux' }
  if ($IsMacOS) { return 'macos' }
  return 'windows'
}

function Get-CommandOutputOrUnknown {
  param(
    [string]$FilePath,
    [string[]]$Arguments
  )

  try {
    $output = & $FilePath @Arguments 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$output)) {
      return ([string]$output).Trim().Split([Environment]::NewLine)[0]
    }
  }
  catch {
  }

  return 'unknown'
}

function Get-SettingsObject {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return $null
  }

  try {
    return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
  }
  catch {
    return $null
  }
}

function Get-SettingsHash {
  param([string]$Path)

  $settings = Get-SettingsObject -Path $Path
  if ($null -eq $settings) {
    return $null
  }

  $canonicalJson = Convert-ToCanonicalJson -Value $settings
  return ('sha256:' + (Get-Sha256Hex -InputText $canonicalJson))
}

function Get-SettingsValue {
  param(
    $SettingsObject,
    [string]$Key
  )

  if ($null -eq $SettingsObject) {
    return $null
  }

  $property = $SettingsObject.PSObject.Properties[$Key]
  if ($null -eq $property) {
    return $null
  }

  return $property.Value
}

function Get-ExtensionState {
  param([string[]]$Prefixes)

  $roots = @(
    (Join-Path $HOME '.vscode\extensions'),
    (Join-Path $HOME '.vscode-insiders\extensions')
  )

  foreach ($root in $roots) {
    if (-not (Test-Path $root)) {
      continue
    }

    foreach ($prefix in $Prefixes) {
      $match = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$prefix-*" } | Select-Object -First 1
      if ($match) {
        return 'installed'
      }
    }
  }

  return 'missing'
}

function Resolve-RunId {
  param([string]$ExplicitRunId)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRunId)) {
    return $ExplicitRunId
  }

  if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) {
    return [string]$env:GITHUB_RUN_ID
  }

  if (-not [string]::IsNullOrWhiteSpace($env:MIXVY_RUN_ID)) {
    return [string]$env:MIXVY_RUN_ID
  }

  return 'local'
}

$settings = Get-SettingsObject -Path $SettingsPath
$vscodeVersion = if ($env:TERM_PROGRAM -eq 'vscode' -and -not [string]::IsNullOrWhiteSpace($env:TERM_PROGRAM_VERSION)) {
  $env:TERM_PROGRAM_VERSION
} else {
  Get-CommandOutputOrUnknown -FilePath 'code' -Arguments @('--version')
}

$resolvedRunId = Resolve-RunId -ExplicitRunId $RunId
$settingsHash = Get-SettingsHash -Path $SettingsPath
$autoGuessEncoding = Get-SettingsValue -SettingsObject $settings -Key 'files.autoGuessEncoding'
$detectIndentation = Get-SettingsValue -SettingsObject $settings -Key 'editor.detectIndentation'

$powershellExtensionState = Get-ExtensionState -Prefixes @('ms-vscode.powershell')
$dartExtensionState = Get-ExtensionState -Prefixes @('dart-code.dart-code')
$flutterExtensionState = Get-ExtensionState -Prefixes @('dart-code.flutter')

$payload = [ordered]@{
  contractType = 'dev_environment'
  contractVersion = 'mixvy.dev_environment_contract.v1'
  generatedAtRunId = $resolvedRunId
  summaryFlags = [ordered]@{
    settingsPresent = ($null -ne $settings)
    settingsHashPresent = (-not [string]::IsNullOrWhiteSpace($settingsHash))
    utf8NoBomPreferred = ($autoGuessEncoding -eq $false)
    detectIndentationDisabled = ($detectIndentation -eq $false)
    powershellExtensionInstalled = ($powershellExtensionState -eq 'installed')
    dartExtensionInstalled = ($dartExtensionState -eq 'installed')
    flutterExtensionInstalled = ($flutterExtensionState -eq 'installed')
  }
  environment = [ordered]@{
    os = Get-OsClass
    shell = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    node = Get-CommandOutputOrUnknown -FilePath 'node' -Arguments @('--version')
    powershell = $PSVersionTable.PSVersion.ToString()
    class = if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') { 'ci' } else { 'local' }
  }
  editor = [ordered]@{
    host = if ($env:TERM_PROGRAM -eq 'vscode') { 'vscode' } else { 'unknown' }
    vscode = $vscodeVersion
    settingsHash = $settingsHash
    detectIndentation = $detectIndentation
  }
  encoding = [ordered]@{
    autoGuessEncoding = $autoGuessEncoding
    utf8NoBomPreferred = if ($autoGuessEncoding -eq $false) { $true } else { $false }
  }
  extensions = [ordered]@{
    powershell = $powershellExtensionState
    dart = $dartExtensionState
    flutter = $flutterExtensionState
  }
}

$payloadHash = 'sha256:' + (Get-Sha256Hex -InputText (Convert-ToCanonicalJson -Value $payload))

$contract = [ordered]@{
  contractType = [string]$payload.contractType
  contractVersion = [string]$payload.contractVersion
  generatedAtRunId = [string]$payload.generatedAtRunId
  contentHash = $payloadHash
  summaryFlags = Convert-ToCanonicalData -Value $payload.summaryFlags
  environment = Convert-ToCanonicalData -Value $payload.environment
  editor = Convert-ToCanonicalData -Value $payload.editor
  encoding = Convert-ToCanonicalData -Value $payload.encoding
  extensions = Convert-ToCanonicalData -Value $payload.extensions
}

if (Test-Path $OutputPath) {
  try {
    $existing = Get-Content -Path $OutputPath -Raw | ConvertFrom-Json
    if ($existing.generatedAtRunId -eq $resolvedRunId) {
      Write-Host "[dev-environment-contract] Skipped overwrite for runId=$resolvedRunId (immutable per run)."
      exit 0
    }
  }
  catch {
    # Existing malformed file is replaced on new run IDs.
  }
}

$json = $contract | ConvertTo-Json -Depth 20
Write-Utf8NoBom -Path $OutputPath -Content $json
Write-Host "[dev-environment-contract] Wrote $OutputPath (runId=$resolvedRunId hash=$payloadHash)"