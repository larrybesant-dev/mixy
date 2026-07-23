param(
  [int]$Port = 8080,
  [ValidateSet('Safe', 'Force')]
  [string]$Mode = 'Safe',
  [ValidateSet('auto', 'ci', 'local', 'unknown')]
  [string]$ExecutionEnvironment = 'auto',
  [int]$TimeoutSeconds = 45,
  [int]$PollIntervalMs = 500,
  [int]$StabilizationSeconds = 3,
  [switch]$BreakRestartLoop,
  [string]$OutputPath = 'artifacts/preflight_contract.json'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Write-Info {
  param([string]$Message)
  Write-Host "[preflight] $Message"
}

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )

  New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force | Out-Null
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
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

function Get-PrivilegeClass {
  param(
    [bool]$IsAdmin,
    [string]$EnvironmentClass
  )

  if ($IsAdmin) {
    return 'admin'
  }

  if ($EnvironmentClass -eq 'ci') {
    return 'restricted'
  }

  if ($EnvironmentClass -eq 'local') {
    return 'non-admin'
  }

  return 'restricted'
}

function Get-ProcessMetadata {
  param([int]$TargetProcessId)

  $name = $null
  $path = $null

  try {
    $proc = Get-Process -Id $TargetProcessId -ErrorAction Stop
    $name = [string]$proc.ProcessName
  } catch {
    $name = $null
  }

  try {
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId = $TargetProcessId" -ErrorAction SilentlyContinue
    if ($cim) {
      $path = [string]$cim.ExecutablePath
    }
  } catch {
    $path = $null
  }

  return [ordered]@{
    pid = $TargetProcessId
    processName = if ([string]::IsNullOrWhiteSpace($name)) { $null } else { $name }
    executablePath = if ([string]::IsNullOrWhiteSpace($path)) { $null } else { $path }
  }
}

function Get-ListenerSnapshot {
  param([int[]]$Pids)

  $snapshots = @()
  foreach ($pid in @($Pids | Select-Object -Unique)) {
    $services = @(Get-CimInstance Win32_Service -Filter "ProcessId = $pid" -ErrorAction SilentlyContinue)
    $metadata = Get-ProcessMetadata -TargetProcessId $pid

    if ($services.Count -gt 0) {
      foreach ($svc in $services) {
        $ownership = if ([string]$svc.StartName -eq 'LocalSystem' -or [string]$svc.StartName -eq 'NT AUTHORITY\\SYSTEM') { 'system_service' } else { 'service' }
        $snapshots += [ordered]@{
          pid = $pid
          ownership = $ownership
          serviceName = [string]$svc.Name
          serviceStartName = [string]$svc.StartName
          processName = $metadata.processName
          executablePath = $metadata.executablePath
        }
      }
    } else {
      if ($pid -eq 4) {
        $snapshots += [ordered]@{
          pid = $pid
          ownership = 'kernel_listener'
          serviceName = 'HTTP.sys'
          serviceStartName = 'kernel'
          processName = 'System'
          executablePath = $null
        }
      } else {
        $snapshots += [ordered]@{
          pid = $pid
          ownership = 'process'
          serviceName = $null
          serviceStartName = $null
          processName = $metadata.processName
          executablePath = $metadata.executablePath
        }
      }
    }
  }

  return @($snapshots)
}

function Resolve-TopReasonCode {
  param($Blocks)

  if ($null -eq $Blocks -or @($Blocks).Count -eq 0) {
    return 'none'
  }

  foreach ($entry in @($Blocks)) {
    if ($null -ne $entry -and [string]$entry.reasonCode -eq 'external_service_blocking_port') {
      return 'external_service_blocking_port'
    }
  }

  return [string]$Blocks[0].reasonCode
}

function Write-PreflightContract {
  param(
    [string]$Path,
    [int]$TargetPort,
    [string]$RunMode,
    [string]$EnvironmentClass,
    [string]$OsClass,
    [bool]$IsAdmin,
    [string]$PrivilegeClass,
    [int[]]$InitialPids,
    [int[]]$FinalPids,
    [bool]$Stable,
    $Blocks,
    [string]$Status,
    [string]$ReasonCode
  )

  $initialListeners = Get-ListenerSnapshot -Pids @($InitialPids)
  $finalListeners = Get-ListenerSnapshot -Pids @($FinalPids)

  $contract = [ordered]@{
    contractVersion = 'mixvy.preflight_contract.v1'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    status = $Status
    reasonCode = $ReasonCode
    environment = [ordered]@{
      class = $EnvironmentClass
      os = $OsClass
      privilegeClass = $PrivilegeClass
      isAdmin = $IsAdmin
    }
    preflight = [ordered]@{
      mode = $RunMode
      port = [int]$TargetPort
      stable = $Stable
      initialListeners = @($initialListeners)
      finalListeners = @($finalListeners)
      blocks = @($Blocks)
    }
  }

  Write-Utf8NoBom -Path $Path -Content ($contract | ConvertTo-Json -Depth 15)
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-ExecutionEnvironment {
  param([string]$Raw)

  if ($Raw -and $Raw -ne 'auto') {
    return $Raw
  }

  if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
    return 'ci'
  }

  if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) {
    return 'local'
  }

  return 'unknown'
}

function Get-ListeningPids {
  param([int]$TargetPort)

  try {
    $connections = Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction Stop
    if (-not $connections) {
      return @()
    }

    return @($connections | Select-Object -ExpandProperty OwningProcess -Unique)
  } catch {
    # Fallback path for constrained environments where NetTCP cmdlets are unavailable.
    $netstatLines = netstat -ano -p tcp | Select-String -Pattern "^\s*TCP\s+\S+:$TargetPort\s+\S+\s+LISTENING\s+(\d+)\s*$"
    if (-not $netstatLines) {
      return @()
    }

    $pids = @()
    foreach ($line in $netstatLines) {
      $match = [regex]::Match($line.Line, "^\s*TCP\s+\S+:$TargetPort\s+\S+\s+LISTENING\s+(\d+)\s*$")
      if ($match.Success) {
        $pids += [int]$match.Groups[1].Value
      }
    }

    return @($pids | Select-Object -Unique)
  }
}

function Wait-ServiceStopped {
  param(
    [string]$ServiceName,
    [int]$WaitSeconds,
    [int]$PollMs
  )

  $deadline = (Get-Date).AddSeconds($WaitSeconds)
  do {
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $svc -or $svc.Status -eq 'Stopped') {
      return $true
    }
    Start-Sleep -Milliseconds $PollMs
  } while ((Get-Date) -lt $deadline)

  return $false
}

function Disable-ServiceRestartPolicies {
  param([string]$ServiceName)

  Write-Info "Disabling restart actions for service '$ServiceName' (explicit override enabled)."
  & sc.exe failure $ServiceName reset= 0 actions= "" | Out-Null
  & sc.exe config $ServiceName start= demand | Out-Null
}

function Invoke-SafeProcessTermination {
  param([int]$TargetProcessId)

  try {
    & taskkill.exe /F /PID $TargetProcessId /T | Out-Null
    if ($LASTEXITCODE -eq 0) {
      return [ordered]@{ status = 'success'; reasonCode = 'none' }
    }

    return [ordered]@{ status = 'failed'; reasonCode = 'probe_failure' }
  } catch {
    $message = [string]$_.Exception.Message
    if ($message -match 'Access is denied') {
      return [ordered]@{ status = 'blocked'; reasonCode = 'env_privilege_blocked' }
    }

    return [ordered]@{ status = 'failed'; reasonCode = 'probe_failure' }
  }
}

function Stop-ServiceDeterministic {
  param(
    [string]$ServiceName,
    [int]$WaitSeconds,
    [int]$PollMs,
    [switch]$AllowBreakLoop
  )

  Write-Info "Query service state: sc queryex $ServiceName"
  & sc.exe queryex $ServiceName | Out-Host

  try {
    Write-Info "Stopping service with Stop-Service: $ServiceName"
    Stop-Service -Name $ServiceName -ErrorAction Stop
  } catch {
    Write-Info "Stop-Service failed for '$ServiceName': $($_.Exception.Message)"
  }

  # Always attempt SCM stop path explicitly to support hosts where Stop-Service is constrained.
  Write-Info "Stopping service with sc stop: $ServiceName"
  $scStopOutput = & sc.exe stop $ServiceName 2>&1
  $scStopOutput | Out-Host

  $scStopText = ($scStopOutput | Out-String)
  if ($scStopText -match 'FAILED\s+5|Access is denied') {
    Write-Info "SCM stop denied for service '$ServiceName'; elevation is required."
    return $false
  }

  if (Wait-ServiceStopped -ServiceName $ServiceName -WaitSeconds $WaitSeconds -PollMs $PollMs) {
    Write-Info "Service '$ServiceName' is stopped."
    return $true
  }

  if ($AllowBreakLoop) {
    try {
      Disable-ServiceRestartPolicies -ServiceName $ServiceName
      Write-Info "Retrying service stop after restart-policy override: $ServiceName"
      & sc.exe stop $ServiceName | Out-Null
      if (Wait-ServiceStopped -ServiceName $ServiceName -WaitSeconds $WaitSeconds -PollMs $PollMs) {
        Write-Info "Service '$ServiceName' stopped after restart-policy override."
        return $true
      }
    } catch {
      Write-Info "Restart-policy override failed for '$ServiceName': $($_.Exception.Message)"
    }
  }

  Write-Info "Service '$ServiceName' did not reach Stopped state within timeout."
  return $false
}

function Wait-PortFreeStable {
  param(
    [int]$TargetPort,
    [int]$StableSeconds,
    [int]$PollMs,
    [int]$MaxWaitSeconds
  )

  $mustStayFreeUntil = (Get-Date).AddSeconds($StableSeconds)
  $deadline = (Get-Date).AddSeconds($MaxWaitSeconds)

  do {
    $pids = Get-ListeningPids -TargetPort $TargetPort
    if ($pids.Count -eq 0) {
      if ((Get-Date) -ge $mustStayFreeUntil) {
        return $true
      }
    } else {
      $mustStayFreeUntil = (Get-Date).AddSeconds($StableSeconds)
    }
    Start-Sleep -Milliseconds $PollMs
  } while ((Get-Date) -lt $deadline)

  return $false
}

function Stop-IisHttpSysOwners {
  param(
    [int]$WaitSeconds,
    [int]$PollMs
  )

  foreach ($svcName in @('W3SVC', 'WAS')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
      continue
    }

    Write-Info "Attempting stop for HTTP.sys edge service '$svcName'."
    try {
      Stop-Service -Name $svcName -ErrorAction Stop
    } catch {
      Write-Info "Stop-Service failed for '$svcName': $($_.Exception.Message)"
    }

    $svcStopOutput = & sc.exe stop $svcName 2>&1
    $svcStopOutput | Out-Host
    Wait-ServiceStopped -ServiceName $svcName -WaitSeconds $WaitSeconds -PollMs $PollMs | Out-Null
  }
}

Write-Info "Starting preflight guard on port $Port in mode '$Mode'."
$isAdmin = Test-IsAdmin
$resolvedEnvironment = Resolve-ExecutionEnvironment -Raw $ExecutionEnvironment
$osClass = Get-OsClass
$privilegeClass = Get-PrivilegeClass -IsAdmin $isAdmin -EnvironmentClass $resolvedEnvironment
if ($resolvedEnvironment -eq 'ci' -and $Mode -eq 'Safe') {
  Write-Info "CI environment detected: elevating from Safe mode to Force mode for deterministic cleanup."
  $Mode = 'Force'
}
Write-Info "Execution environment: $resolvedEnvironment"
Write-Info "Admin session: $isAdmin"

$initialPids = Get-ListeningPids -TargetPort $Port
if ($initialPids.Count -eq 0) {
  Write-Info "Port $Port is already free."
  Write-PreflightContract -Path $OutputPath -TargetPort $Port -RunMode $Mode -EnvironmentClass $resolvedEnvironment -OsClass $osClass -IsAdmin $isAdmin -PrivilegeClass $privilegeClass -InitialPids @() -FinalPids @() -Stable $true -Blocks @() -Status 'pass' -ReasonCode 'none'
  exit 0
}

Write-Info "Port $Port listeners at start: $($initialPids -join ', ')"

$overallSuccess = $true
$blockingClassifications = @()

foreach ($listenerPid in $initialPids) {
  $services = @(Get-CimInstance Win32_Service -Filter "ProcessId = $listenerPid" -ErrorAction SilentlyContinue)
  if ($services.Count -gt 0) {
    foreach ($svc in $services) {
      Write-Info "PID $listenerPid maps to service '$($svc.Name)' running as '$($svc.StartName)'."

      # Deterministic classifier rule: service-owned listeners are never force-killed by preflight.
      $ownerClass = if ([string]$svc.StartName -eq 'LocalSystem' -or [string]$svc.StartName -eq 'NT AUTHORITY\\SYSTEM') { 'system_service' } else { 'service' }
      $blockingClassifications += [ordered]@{
        reasonCode = 'external_service_blocking_port'
        pid = $listenerPid
        serviceName = [string]$svc.Name
        serviceStartName = [string]$svc.StartName
        ownership = $ownerClass
      }
      Write-Info "Classified blocking owner for PID ${listenerPid}: external_service_blocking_port ($ownerClass)."
      $overallSuccess = $false
    }
  } else {
    Write-Info "PID $listenerPid has no SCM service owner."
    if ($listenerPid -eq 4) {
      Write-Info "PID 4 indicates HTTP.sys kernel listener; classifying as kernel ownership block."
      $blockingClassifications += [ordered]@{
        reasonCode = 'external_service_blocking_port'
        pid = $listenerPid
        serviceName = 'HTTP.sys'
        serviceStartName = 'kernel'
        ownership = 'kernel_listener'
      }
      $overallSuccess = $false
      continue
    }

    if ($Mode -eq 'Force') {
      Write-Info "Force mode: taskkill /F /PID $listenerPid /T"
      $termination = Invoke-SafeProcessTermination -TargetProcessId $listenerPid
      Write-Info "Termination attempt result for PID ${listenerPid}: $($termination.status) / $($termination.reasonCode)"
      if ($termination.status -ne 'success') {
        $blockingClassifications += [ordered]@{
          reasonCode = $termination.reasonCode
          pid = $listenerPid
          serviceName = $null
          serviceStartName = $null
          ownership = 'process'
        }
        $overallSuccess = $false
      }
    } else {
      Write-Info "Safe mode refuses PID kill; leaving process untouched."
      $blockingClassifications += [ordered]@{
        reasonCode = 'safe_mode_refused_termination'
        pid = $listenerPid
        serviceName = $null
        serviceStartName = $null
        ownership = 'process'
      }
      $overallSuccess = $false
    }
  }
}

$stable = Wait-PortFreeStable -TargetPort $Port -StableSeconds $StabilizationSeconds -PollMs $PollIntervalMs -MaxWaitSeconds $TimeoutSeconds
$finalListeners = Get-ListeningPids -TargetPort $Port

if ($overallSuccess -and $stable -and $finalListeners.Count -eq 0) {
  Write-Info "Port $Port is free and stable."
}

if ($finalListeners.Count -gt 0) {
  Write-Info "Port $Port is still occupied by PID(s): $($finalListeners -join ', ')"
  foreach ($finalPid in $finalListeners) {
    $owners = @(Get-CimInstance Win32_Service -Filter "ProcessId = $finalPid" -ErrorAction SilentlyContinue)
    if ($owners.Count -gt 0) {
      foreach ($owner in $owners) {
        Write-Info "Listener PID $finalPid service owner: $($owner.Name) ($($owner.DisplayName))"
      }
    } else {
      Write-Info "Listener PID $finalPid has no SCM service mapping."
    }
  }
}

if ($blockingClassifications.Count -gt 0) {
  $classificationSummary = $blockingClassifications | ConvertTo-Json -Depth 8 -Compress
  Write-Info "Blocking classifications: $classificationSummary"
}

$status = if ($overallSuccess -and $stable -and $finalListeners.Count -eq 0) { 'pass' } elseif ($blockingClassifications.Count -gt 0 -or $finalListeners.Count -gt 0) { 'blocked' } else { 'failed' }
$reasonCode = if ($status -eq 'pass') { 'none' } elseif ($status -eq 'blocked') { Resolve-TopReasonCode -Blocks $blockingClassifications } else { 'probe_failure' }

Write-PreflightContract -Path $OutputPath -TargetPort $Port -RunMode $Mode -EnvironmentClass $resolvedEnvironment -OsClass $osClass -IsAdmin $isAdmin -PrivilegeClass $privilegeClass -InitialPids @($initialPids) -FinalPids @($finalListeners) -Stable $stable -Blocks @($blockingClassifications) -Status $status -ReasonCode $reasonCode

if ($status -eq 'pass') {
  Write-Info "Preflight passed for port $Port."
} else {
  Write-Info "Preflight classified port $Port as $status ($reasonCode)."
}

# Sensor-only contract: preflight emits observations and never makes deploy gate decisions.
exit 0