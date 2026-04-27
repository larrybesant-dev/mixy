Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot

function Fail([string]$message) {
    Write-Error $message
    exit 1
}

function Assert-FileMissing([string]$path) {
    if (Test-Path $path) {
        Fail "Forbidden file exists: $path"
    }
}

function Assert-FileContains([string]$path, [string]$pattern, [string]$message) {
    if (-not (Test-Path $path)) {
        Fail "Required file missing: $path"
    }

    $content = Get-Content -Path $path -Raw
    if ($content -notmatch $pattern) {
        Fail $message
    }
}

function Get-DartFiles([string]$root = 'lib') {
    return Get-ChildItem -Path $root -Recurse -File -Filter '*.dart'
}

function To-RepoRelativePath([string]$fullPath) {
    if ([string]::IsNullOrWhiteSpace($fullPath)) {
        return $fullPath
    }

    $normalizedRoot = ([System.IO.Path]::GetFullPath(($repoRoot -replace '/', '\'))).TrimEnd('\') + '\'
    $normalizedPath = [System.IO.Path]::GetFullPath(($fullPath -replace '/', '\'))

    if ($normalizedPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedPath.Substring($normalizedRoot.Length).Replace('\', '/')
    }

    $libAnchorIndex = $normalizedPath.ToLowerInvariant().IndexOf('\lib\')
    if ($libAnchorIndex -ge 0) {
        return $normalizedPath.Substring($libAnchorIndex + 1).Replace('\', '/')
    }

    return $normalizedPath.Replace('\', '/')
}

function Count-Matches([System.IO.FileInfo[]]$files, [string]$pattern) {
    $count = 0
    foreach ($file in $files) {
        $content = Get-Content -Path $file.FullName -Raw
        if ($null -eq $content) {
            $content = ''
        }
        $matches = [regex]::Matches($content, $pattern)
        $count += $matches.Count
    }
    return $count
}

function Find-MatchingFiles([System.IO.FileInfo[]]$files, [string]$pattern) {
    $hits = @()
    foreach ($file in $files) {
        $content = Get-Content -Path $file.FullName -Raw
        if ($null -eq $content) {
            $content = ''
        }
        if ($content -match $pattern) {
            $hits += $file.FullName
        }
    }
    return $hits
}

function Assert-FollowsSnapshotsCentralized([System.IO.FileInfo[]]$files) {
    $allowedOwner = 'lib/services/follow_service.dart'
    $violations = @()

    foreach ($file in $files) {
        $content = Get-Content -Path $file.FullName -Raw
        if ($null -eq $content) {
            $content = ''
        }

        # Guardrail: follow graph realtime listeners must be centralized.
        # Disallow any direct follows `.snapshots()` pipeline outside FollowService.
        $hasFollowsSnapshots =
            ($content -match "(?s)collection\('follows'\).*?snapshots\s*\(") -or
            ($content -match '(?s)collection\("follows"\).*?snapshots\s*\(')
        if ($hasFollowsSnapshots) {
            $rel = To-RepoRelativePath $file.FullName
            if ($rel -ne $allowedOwner) {
                $violations += $rel
            }
        }
    }

    if ($violations.Count -gt 0) {
        $joined = ($violations | Sort-Object -Unique) -join ', '
        Fail "Follow graph stream guardrail violation: direct follows snapshots are only allowed in $allowedOwner. Found in: $joined"
    }
}

function Resolve-ImportTarget([string]$currentRelPath, [string]$importSpec) {
    if ([string]::IsNullOrWhiteSpace($importSpec)) {
        return $null
    }

    $candidateFullPath = $null

    if ($importSpec.StartsWith('package:mixvy/')) {
        $packagePath = $importSpec.Substring('package:mixvy/'.Length).Replace('/', '\')
        $candidateFullPath = Join-Path $repoRoot (Join-Path 'lib' $packagePath)
    }
    elseif ($importSpec.StartsWith('./') -or $importSpec.StartsWith('../')) {
        $currentFullPath = Join-Path $repoRoot ($currentRelPath.Replace('/', '\'))
        $currentDir = Split-Path -Path $currentFullPath -Parent
        $candidateFullPath = Join-Path $currentDir ($importSpec.Replace('/', '\'))
    }
    else {
        return $null
    }

    if (Test-Path $candidateFullPath) {
        $resolved = (Resolve-Path $candidateFullPath).Path
        if ($resolved.ToLowerInvariant().EndsWith('.dart')) {
            return To-RepoRelativePath $resolved
        }
    }

    return $null
}

function Build-ImportGraph([System.IO.FileInfo[]]$files) {
    $graph = @{}
    $importRegex = [regex]'import\s+["'']([^"'']+)["'']\s*;'

    foreach ($file in $files) {
        $fileFullPath = (Resolve-Path $file.FullName).Path
        $fileRelPath = To-RepoRelativePath $fileFullPath
        $graph[$fileRelPath] = @()

        $content = Get-Content -Path $file.FullName -Raw
        if ($null -eq $content) {
            $content = ''
        }

        $matches = $importRegex.Matches($content)
        foreach ($match in $matches) {
            $importSpec = $match.Groups[1].Value
            $target = Resolve-ImportTarget -currentRelPath $fileRelPath -importSpec $importSpec
            if ($null -ne $target) {
                $graph[$fileRelPath] += $target
            }
        }
    }

    return $graph
}

function Assert-NoPrototypeReachableFromMain([hashtable]$graph) {
    $root = 'lib/main.dart'
    if (-not $graph.ContainsKey($root)) {
        $keys = @($graph.Keys | Sort-Object) -join ', '
        Fail "Import graph root missing: lib/main.dart. Graph keys: $keys"
    }

    $queue = [System.Collections.Generic.Queue[string]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $parent = @{}

    $queue.Enqueue($root)
    [void]$visited.Add($root)

    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        $neighbors = @()
        if ($graph.ContainsKey($node)) {
            $neighbors = @($graph[$node])
        }

        foreach ($neighbor in $neighbors) {
            if ($neighbor -like 'lib/dev/prototype/*') {
                $chain = @($neighbor)
                $cursor = $node
                while ($null -ne $cursor) {
                    $chain = @($cursor) + $chain
                    if ($parent.ContainsKey($cursor)) {
                        $cursor = $parent[$cursor]
                    }
                    else {
                        $cursor = $null
                    }
                }

                $message = 'Prototype code is reachable from lib/main.dart via imports: ' + ($chain -join ' -> ')
                Fail $message
            }

            if (-not $visited.Contains($neighbor)) {
                [void]$visited.Add($neighbor)
                $parent[$neighbor] = $node
                $queue.Enqueue($neighbor)
            }
        }
    }
}

Write-Host 'Validating MixVy architecture guardrails...'

# 1) Legacy prototype files must not exist in production namespaces.
Assert-FileMissing 'lib/app/mixvy_app.dart'
Assert-FileMissing 'lib/app/router/app_router.dart'

# 2) Boot path must remain stable.
Assert-FileContains 'lib/main.dart' "import\s+'app/app.dart';" 'main.dart must import app/app.dart'
Assert-FileContains 'lib/main.dart' 'ProviderScope\(' 'main.dart must run inside ProviderScope'
Assert-FileContains 'lib/main.dart' 'MixVyApp\(' 'main.dart must launch MixVyApp'

# 3) Production app shell must exist and remain unique.
Assert-FileContains 'lib/app/app.dart' 'class\s+MixVyApp\b' 'lib/app/app.dart must define MixVyApp'

$dartFiles = Get-DartFiles
$mixVyAppCount = Count-Matches -files $dartFiles -pattern 'class\s+MixVyApp\b'
if ($mixVyAppCount -ne 1) {
    Fail "Expected exactly one MixVyApp class. Found: $mixVyAppCount"
}

# 4) Single-router rule: exactly one GoRouter declaration, owned by lib/router/app_router.dart.
$goRouterFiles = @(Find-MatchingFiles -files $dartFiles -pattern '\bGoRouter\s*\(')
$uniqueGoRouterFiles = @($goRouterFiles | Sort-Object -Unique)

if ($uniqueGoRouterFiles.Count -ne 1) {
    $joined = ($uniqueGoRouterFiles | ForEach-Object { To-RepoRelativePath $_ }) -join ', '
    Fail "Expected exactly one GoRouter owner file. Found: $($uniqueGoRouterFiles.Count). Files: $joined"
}

$singleOwner = To-RepoRelativePath $uniqueGoRouterFiles[0]
if ($singleOwner -notmatch '(^|[\\/])lib[\\/]router[\\/]app_router\.dart$') {
    Fail "GoRouter owner must be lib/router/app_router.dart. Found: $singleOwner"
}

# 5) Production must not import prototype namespace.
$prodFiles = Get-ChildItem -Path 'lib' -Recurse -File -Filter '*.dart' |
    Where-Object { $_.FullName -notmatch '\\lib\\dev\\prototype\\' }

$prototypeImportHits = @(Find-MatchingFiles -files $prodFiles -pattern 'import\s+.*dev/prototype/')
if ($prototypeImportHits.Count -gt 0) {
    $joined = ($prototypeImportHits | Sort-Object -Unique) -join ', '
    Fail "Production files import dev/prototype code: $joined"
}

# 6) Stitch prototype viewer symbols must not leak into production.
$stitchLeakHits = @(Find-MatchingFiles -files $prodFiles -pattern '\bStitchPrototype(App|Router|Viewer|FileViewer)\b|\bStitchViewer\b')
if ($stitchLeakHits.Count -gt 0) {
    $joined = ($stitchLeakHits | Sort-Object -Unique) -join ', '
    Fail "Prototype symbols leaked into production files: $joined"
}

# 7) Import graph guard: main.dart dependency closure must never reach prototype code.
$graph = Build-ImportGraph -files $dartFiles
Assert-NoPrototypeReachableFromMain -graph $graph

# 8) Follows realtime ownership guardrail.
Assert-FollowsSnapshotsCentralized -files $dartFiles

Write-Host 'Architecture guardrails validated successfully.'
Pop-Location
exit 0

