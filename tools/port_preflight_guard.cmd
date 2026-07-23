@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PORT=8080"
set "MODE=SAFE"
set "TIMEOUT=45"
set "POLL=1"
set "STABLE=3"
set "EXEC_ENV=auto"

if /I not "%~1"=="" set "PORT=%~1"
if /I not "%~2"=="" set "MODE=%~2"
if /I not "%~3"=="" set "TIMEOUT=%~3"
if /I not "%~4"=="" set "STABLE=%~4"
if /I not "%~5"=="" set "EXEC_ENV=%~5"

if /I "%EXEC_ENV%"=="auto" (
  if /I "%GITHUB_ACTIONS%"=="true" set "EXEC_ENV=ci"
  if /I "%CI%"=="true" set "EXEC_ENV=ci"
  if /I "%EXEC_ENV%"=="auto" set "EXEC_ENV=local"
)

if /I "%EXEC_ENV%"=="ci" if /I "%MODE%"=="SAFE" set "MODE=FORCE"

set "ISADMIN=1"
net session >nul 2>&1
if errorlevel 1 set "ISADMIN=0"

echo [preflight] Port=%PORT% Mode=%MODE% Timeout=%TIMEOUT%s Stable=%STABLE%s Admin=%ISADMIN% Env=%EXEC_ENV%

set "PIDS="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do (
  call :AppendPid %%P
)

if "%PIDS%"=="" (
  echo [preflight] Port %PORT% is already free.
  exit /b 0
)

echo [preflight] Initial listener PID(s): %PIDS%

set "SUCCESS=1"
for %%P in (%PIDS%) do (
  set "PID=%%P"
  call :StopByService !PID!
)

call :WaitPortFree
if errorlevel 1 (
  echo [preflight] Preflight failed: port %PORT% is still occupied.
  exit /b 1
)

if "%SUCCESS%"=="1" (
  echo [preflight] Port %PORT% is free and stable.
  exit /b 0
)

echo [preflight] Preflight failed due to mode restrictions.
exit /b 1

:AppendPid
set "NEWPID=%~1"
for %%E in (%PIDS%) do if "%%E"=="%NEWPID%" goto :eof
if "%PIDS%"=="" (
  set "PIDS=%NEWPID%"
) else (
  set "PIDS=%PIDS% %NEWPID%"
)
goto :eof

:StopByService
set "TARGETPID=%~1"
set "SVCNAME="
set "FOUND_SERVICE=0"

for /f "tokens=2 delims=:" %%S in ('sc query state^= all ^| findstr /B /C:"SERVICE_NAME:"') do (
  set "CANDIDATE=%%S"
  set "CANDIDATE=!CANDIDATE:~1!"
  for /f "tokens=2 delims=:" %%I in ('sc queryex "!CANDIDATE!" ^| findstr /R /C:"PID *:"') do (
    set "SERVICEPID=%%I"
    set "SERVICEPID=!SERVICEPID: =!"
    if "!SERVICEPID!"=="%TARGETPID%" (
      set "SVCNAME=!CANDIDATE!"
      set "FOUND_SERVICE=1"
    )
  )
)

if "%FOUND_SERVICE%"=="1" (
  echo [preflight] PID %TARGETPID% maps to service %SVCNAME%.
  if "%ISADMIN%"=="0" (
    echo [preflight] Non-admin session cannot stop SCM service %SVCNAME%.
    if /I "%MODE%"=="FORCE" (
      echo [preflight] Force mode fallback: taskkill /F /PID %TARGETPID% /T
      taskkill /F /PID %TARGETPID% /T >nul 2>&1
    ) else (
      set "SUCCESS=0"
    )
    goto :eof
  )
  sc queryex "%SVCNAME%" >nul 2>&1
  sc stop "%SVCNAME%" >nul 2>&1
  call :WaitServiceStopped "%SVCNAME%"
  if errorlevel 1 (
    if /I "%MODE%"=="FORCE" (
      echo [preflight] Force mode fallback: taskkill /F /PID %TARGETPID% /T
      taskkill /F /PID %TARGETPID% /T >nul 2>&1
    ) else (
      echo [preflight] Safe mode: refusing force kill for PID %TARGETPID%.
      set "SUCCESS=0"
    )
  )
  goto :eof
)

echo [preflight] PID %TARGETPID% has no service owner.
if "%TARGETPID%"=="4" (
  echo [preflight] PID 4 detected. Attempting IIS HTTP.sys owner shutdown via WAS/W3SVC.
  sc stop WAS >nul 2>&1
  call :WaitServiceStopped "WAS"
  sc stop W3SVC >nul 2>&1
  call :WaitServiceStopped "W3SVC"
  goto :eof
)

if /I "%MODE%"=="FORCE" (
  echo [preflight] Force mode: taskkill /F /PID %TARGETPID% /T
  taskkill /F /PID %TARGETPID% /T >nul 2>&1
) else (
  echo [preflight] Safe mode: refusing force kill for PID %TARGETPID%.
  set "SUCCESS=0"
)
goto :eof

:WaitServiceStopped
set "CHECKS=%TIMEOUT%"
:WaitServiceLoop
sc query "%~1" | find "STATE" | find "STOPPED" >nul 2>&1
if not errorlevel 1 exit /b 0
set /a CHECKS-=1
if %CHECKS% LEQ 0 exit /b 1
timeout /t %POLL% /nobreak >nul
goto :WaitServiceLoop

:WaitPortFree
set "CHECKS=%TIMEOUT%"
set /a STABLECHECKS=%STABLE%/%POLL%
if %STABLECHECKS% LEQ 0 set "STABLECHECKS=1"
set "FREECOUNT=0"
:WaitPortLoop
set "FOUND="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do (
  set "FOUND=1"
)
if not defined FOUND (
  set /a FREECOUNT+=1
) else (
  set "FREECOUNT=0"
)
if %FREECOUNT% GEQ %STABLECHECKS% exit /b 0
set /a CHECKS-=1
if %CHECKS% LEQ 0 exit /b 1
timeout /t %POLL% /nobreak >nul
goto :WaitPortLoop