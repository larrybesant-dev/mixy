#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[governance] validating frozen interpretation contract"

CONTRACT_FILE="lib/features/schema_messenger/consistency/architecture_health_interpretation_contract.dart"
PROVIDER_FILE="lib/features/schema_messenger/consistency/architecture_health_interpretation_provider.dart"
EXPECTED_VERSION="static const String version = 'v1_frozen_2026_04_12';"
SYMBOL="architectureHealthInterpretationProvider"

if [[ ! -f "$CONTRACT_FILE" ]]; then
  echo "ERROR: missing contract file: $CONTRACT_FILE"
  exit 1
fi

if [[ ! -f "$PROVIDER_FILE" ]]; then
  echo "ERROR: missing provider file: $PROVIDER_FILE"
  exit 1
fi

if ! grep -Fq "$EXPECTED_VERSION" "$CONTRACT_FILE"; then
  echo "ERROR: frozen interpretation contract version mismatch"
  exit 1
fi

if ! grep -Fq "policyVersion: ArchitectureHealthInterpretationContract.version" "$PROVIDER_FILE"; then
  echo "ERROR: provider is not pinned to contract version"
  exit 1
fi

if ! grep -Fq "advisoryOnly: true" "$PROVIDER_FILE"; then
  echo "ERROR: provider must remain advisory-only"
  exit 1
fi

echo "[governance] validating interpretation consumption boundaries"

# Allowed consumption surfaces are presentation views and tests.
mapfile -t hits < <(grep -R --line-number --include='*.dart' "$SYMBOL" lib test || true)

violations=0
for hit in "${hits[@]}"; do
  file="${hit%%:*}"

  # Allow symbol definition file.
  if [[ "$file" == "$PROVIDER_FILE" ]]; then
    continue
  fi

  # Allow presentation layer usage.
  if [[ "$file" == *"/views/"* ]]; then
    continue
  fi

  # Allow tests to read interpretation output.
  if [[ "$file" == test/* ]]; then
    continue
  fi

  echo "ERROR: disallowed interpretation usage at $hit"
  violations=1
done

if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "[governance] all checks passed"
