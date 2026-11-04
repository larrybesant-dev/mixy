$ErrorActionPreference = 'Stop'

$javaVersionOutput = (& $env:ComSpec /c 'java -version 2>&1' | Out-String)
if ($javaVersionOutput -notmatch 'version "(?:1\.)?([0-9]+)') {
    throw 'Unable to determine the active Java version.'
}
$javaMajor = [int]$Matches[1]
if ($javaMajor -lt 21) {
    $scoopJava21 = Join-Path $env:USERPROFILE 'scoop\apps\temurin21-jdk\current'
    if (-not (Test-Path (Join-Path $scoopJava21 'bin\java.exe'))) {
        throw 'Firebase emulators require Java 21+. Set JAVA_HOME to a Java 21 installation.'
    }
    $env:JAVA_HOME = $scoopJava21
    $env:PATH = "$(Join-Path $scoopJava21 'bin');$env:PATH"
}

$firebaseCli = '.\node_modules\firebase-tools\lib\bin\firebase.js'
if (-not (Test-Path $firebaseCli)) {
    throw 'Firebase CLI dependency is missing. Run npm ci before the emulator E2E suite.'
}

flutter build web --release --no-pub --base-href / `
    --dart-define=USE_FIREBASE_EMULATORS=true `
    --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 `
    --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099 `
    --dart-define=FIRESTORE_EMULATOR_PORT=8085 `
    --dart-define=FUNCTIONS_EMULATOR_PORT=5001 `
    --dart-define=DISABLE_WEB_APPCHECK=true
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

node $firebaseCli emulators:exec `
    --project mixvy-v2 `
    --only auth,firestore,hosting `
    'node tools/run_local_playwright_e2e.mjs'
exit $LASTEXITCODE
