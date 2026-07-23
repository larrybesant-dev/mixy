#!/usr/bin/env bash
set -euo pipefail

tier="${1:-}"

if [[ -z "$tier" ]]; then
  echo "Usage: bash tools/run_release_gate.sh <tier0|tier1|tier2|room>"
  exit 1
fi

require_cmd() {
  local tool_name="$1"
  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool_name}" >&2
    exit 1
  fi
}

require_cmd flutter
require_cmd unzip

run_case() {
  local case_id="$1"
  shift
  echo "::group::${case_id}"
  "$@"
  echo "::endgroup::"
}

case "$tier" in
  tier0)
    echo "Running Tier 0 hard blockers (MC + PS)"

    run_case "MC-1 Ordering Determinism" \
      flutter test --no-pub test/messages_screen_test.dart

    run_case "MC-2 Duplicate Suppression" \
      flutter test --no-pub test/chat_pane_view_test.dart

    run_case "MC-3 Offline Queue Integrity" \
      flutter test --no-pub test/messaging_retention_test.dart

    run_case "MC-4 Crash Recovery Consistency" \
      flutter test --no-pub test/app_integration_test.dart

    run_case "PS-1 Lifecycle Correctness" \
      flutter test --no-pub test/presence_service_test.dart

    run_case "PS-2 Multi-Device Truth Convergence" \
      flutter test --no-pub test/presence_guardrail_test.dart

    run_case "PS-3 Partition Recovery" \
      flutter test --no-pub test/room_session_stress_test.dart

    run_case "PS-4 Room Dominance Rule" \
      flutter test --no-pub test/live_room_screen_test.dart
    ;;

  tier1)
    echo "Running Tier 1 product usability blockers (NR)"

    run_case "NR-1 Push to Correct Route" \
      flutter test --no-pub test/notification_service_test.dart

    run_case "NR-2 Deep Link Correctness" \
      flutter test --no-pub test/app_router_redirect_test.dart

    run_case "NR-3 No Double Navigation" \
      flutter test --no-pub test/messages_screen_test.dart

    run_case "NR-4 Auth-Aware Routing" \
      flutter test --no-pub test/login_signup_navigation_test.dart
    ;;

  tier2)
    echo "Running Tier 2 confidence gates (CG)"
    echo "Tier 2 policy: errors and warnings block release; info-level lints are advisory only."

    run_case "CG-1 Analyzer (errors and warnings only)" \
      flutter analyze --no-pub --fatal-warnings --no-fatal-infos

    run_case "CG-2 Schema Consistency Tests" \
      flutter test --no-pub test/features/schema_messenger/consistency

    run_case "CG-2 Friends and Presence Critical Tests" \
      flutter test --no-pub test/friend_list_screen_test.dart test/friend_provider_test.dart test/presence_guardrail_test.dart

    run_case "CG-3 Governance Boundaries" \
      bash tools/enforce_governance_boundaries.sh
    ;;

  room)
    echo "Running deterministic room release stress gate (RS)"

    run_case "RS-1 Reconnect Storm" \
      flutter test --no-pub test/room_session_stress_test.dart

    run_case "RS-2 Listener Leak Verification" \
      flutter test --no-pub test/room_chaos_master_test.dart

    run_case "RS-3 Host Authority Stress" \
      flutter test --no-pub test/room_state_machine_test.dart

    run_case "RS-4 Mic Pressure Test" \
      flutter test --no-pub test/room_slot_service_test.dart test/room_host_control_panel_stage_tab_test.dart

    run_case "RS-5 Late Join Sync" \
      flutter test --no-pub test/live_room_screen_test.dart test/room_state_test.dart

    run_case "RS-6 Telemetry Truth Validation" \
      flutter test --no-pub test/app_telemetry_test.dart

    run_case "RS-7 Recovery Baseline Build" \
      flutter build web --release --base-href /
    ;;

  *)
    echo "Unknown tier '$tier'. Expected tier0, tier1, tier2, or room."
    exit 1
    ;;
esac

echo "Tier '$tier' completed successfully."