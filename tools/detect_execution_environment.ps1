param(
  [switch]$JsonOnly,
  [switch]$EmitGitHubEnv
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

$environmentName = 'unknown'
if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
  $environmentName = 'ci'
} elseif (-not [string]::IsNullOrWhiteSpace($env:USERNAME) -or -not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
  $environmentName = 'local'
}

$isAdmin = (Test-IsAdmin)
$privilegeClass = if ($isAdmin) {
  'admin'
} elseif ($environmentName -eq 'ci') {
  'restricted'
} else {
  'non-admin'
}

$result = [ordered]@{
  contractVersion = 'mixvy.execution_environment.v2'
  environment = $environmentName
  privilegeClass = $privilegeClass
  os = (Get-OsClass)
  isAdmin = $isAdmin
}

$json = $result | ConvertTo-Json -Depth 5

if ($EmitGitHubEnv -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
  Add-Content -Path $env:GITHUB_ENV -Value "MIXVY_EXEC_ENV=$($result.environment)"
  Add-Content -Path $env:GITHUB_ENV -Value "MIXVY_EXEC_IS_ADMIN=$($result.isAdmin)"
}

if ($JsonOnly) {
  Write-Output $json
} else {
  Write-Host "[env] $json"
}
