param(
    [ValidateSet('tier0', 'tier1', 'tier2', 'room')]
    [string]$Tier = 'tier2',
    [switch]$SkipWebBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot

function Run-Case {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaseId,
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    Write-Host "::group::$CaseId"
    Invoke-Expression $Command
    $exitCode = $LASTEXITCODE
    Write-Host '::endgroup::'

    if ($exitCode -ne 0) {
        Write-Error "Release gate failed: $CaseId"
        exit $exitCode
    }
}

switch ($Tier) {
    'tier0' {
        Write-Host 'Running Tier 0 hard blockers (MC + PS)'

        Run-Case -CaseId 'MC-1 Ordering Determinism' -Command 'flutter test --no-pub test/messages_screen_test.dart'
        Run-Case -CaseId 'MC-2 Duplicate Suppression' -Command 'flutter test --no-pub test/chat_pane_view_test.dart'
        Run-Case -CaseId 'MC-3 Offline Queue Integrity' -Command 'flutter test --no-pub test/messaging_retention_test.dart'
        Run-Case -CaseId 'MC-4 Crash Recovery Consistency' -Command 'flutter test --no-pub test/app_integration_test.dart'
        Run-Case -CaseId 'PS-1 Lifecycle Correctness' -Command 'flutter test --no-pub test/presence_service_test.dart'
        Run-Case -CaseId 'PS-2 Multi-Device Truth Convergence' -Command 'flutter test --no-pub test/presence_guardrail_test.dart'
        Run-Case -CaseId 'PS-3 Partition Recovery' -Command 'flutter test --no-pub test/room_session_stress_test.dart'
        Run-Case -CaseId 'PS-4 Room Dominance Rule' -Command 'flutter test --no-pub test/live_room_screen_test.dart'
    }

    'tier1' {
        Write-Host 'Running Tier 1 product usability blockers (NR)'

        Run-Case -CaseId 'NR-1 Push to Correct Route' -Command 'flutter test --no-pub test/notification_service_test.dart'
        Run-Case -CaseId 'NR-2 Deep Link Correctness' -Command 'flutter test --no-pub test/app_router_redirect_test.dart'
        Run-Case -CaseId 'NR-3 No Double Navigation' -Command 'flutter test --no-pub test/messages_screen_test.dart'
        Run-Case -CaseId 'NR-4 Auth-Aware Routing' -Command 'flutter test --no-pub test/login_signup_navigation_test.dart'
    }

    'tier2' {
        Write-Host 'Running Tier 2 confidence gates (CG)'
        Write-Host 'Tier 2 policy: errors and warnings block release; info-level lints are advisory only.'

        Run-Case -CaseId 'CG-1 Analyzer (errors and warnings only)' -Command 'flutter analyze --no-pub --fatal-warnings --no-fatal-infos'
        Run-Case -CaseId 'CG-2 Schema Consistency Tests' -Command 'flutter test --no-pub test/features/schema_messenger/consistency'
        Run-Case -CaseId 'CG-2 Friends and Presence Critical Tests' -Command 'flutter test --no-pub test/friend_list_screen_test.dart test/friend_provider_test.dart test/presence_guardrail_test.dart'
        Run-Case -CaseId 'CG-3 Governance Boundaries' -Command 'bash tools/enforce_governance_boundaries.sh'

        if (-not $SkipWebBuild) {
            Run-Case -CaseId 'CG-4 Build web release (informational)' -Command "flutter build web --release --base-href '/'"
        }
    }

    'room' {
        Write-Host 'Running deterministic room release stress gate (RS)'

        Run-Case -CaseId 'RS-1 Reconnect Storm' -Command 'flutter test --no-pub test/room_session_stress_test.dart'
        Run-Case -CaseId 'RS-2 Listener Leak Verification' -Command 'flutter test --no-pub test/room_chaos_master_test.dart'
        Run-Case -CaseId 'RS-3 Host Authority Stress' -Command 'flutter test --no-pub test/room_state_machine_test.dart'
        Run-Case -CaseId 'RS-4 Mic Pressure Test' -Command 'flutter test --no-pub test/room_slot_service_test.dart test/room_host_control_panel_stage_tab_test.dart'
        Run-Case -CaseId 'RS-5 Late Join Sync' -Command 'flutter test --no-pub test/live_room_screen_test.dart test/room_state_test.dart'
        Run-Case -CaseId 'RS-6 Telemetry Truth Validation' -Command 'flutter test --no-pub test/app_telemetry_test.dart'

        if (-not $SkipWebBuild) {
            Run-Case -CaseId 'RS-7 Recovery Baseline Build' -Command "flutter build web --release --base-href '/'"
        }
    }
}

Write-Host "Tier '$Tier' completed successfully."
Pop-Location
exit 0
