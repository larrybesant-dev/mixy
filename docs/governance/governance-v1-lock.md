# Governance Control Plane – v1 Lock

Tag: governance-v1-lock  
Commit: 8de1d52  
Date: 2026-04-13  

## Summary
First schema-enforced governance control plane with non-invasive adaptive tuning.

This document represents the exact operational state of the governance control plane at the time of tag `governance-v1-lock`. All behavior described here is verifiable via emitted artifacts and CI outputs.

## Capabilities Frozen

### 1. Policy Tuning (Sidecar, Recommend-Only)
- Dual-window tuning (short + baseline)
- Weighted blending
- No mutation of release decisions

### 2. Divergence-Aware Guard
- Computes policy_divergence_score
- Blocks tuning on divergence threshold breach
- Emits stall_and_review recommendation

### 3. Burn-In Handling
- Burn-in freeze window
- Early-exit override on severe instability

### 4. Contract Enforcement
- policy_drift_contract.schema.json
- CI validation step
- Required artifact structure enforced

### 5. Artifact Guarantees
CI always emits:
- proposed_thresholds.json
- rc_policy_snapshot_v1.json
- policy_approval_request.json
- policy_tuner_status.json

Fallback artifacts included when tuner fails.

### 6. Approval System
- Manual promotion required
- policy_promotion_receipt.json generated
- Includes explicit policy_delta_summary

### 7. Architecture Separation
- Execution plane (governor)
- Observation plane (snapshots)
- Control plane (tuner + approval)

## Non-Goals (Explicitly Not Included)
- No auto-promotion
- No enforcement from tuner
- No adaptive mutation of live thresholds

## Known Risks (Post-Lock Reality)

1. **Limited Real-World RC Coverage**
   - Current behavior validated on synthetic + initial local runs only
   - Unknown: divergence sensitivity under real regression patterns

2. **Policy Stability Score Immaturity**
   - Score logic implemented but lacks sufficient RC history
   - Risk: misleading confidence until ≥10–15 real RC samples

3. **Policy History Index Bootstrap State**
   - Index initialized from synthetic run
   - Risk: early trend analysis may be skewed until real data dominates

4. **Divergence Classification Confidence**
   - Classification logic exists (transient / spike / structural)
   - Unknown: accuracy under mixed-signal RC behavior

## Verification Criteria for Next Phase

The governance layer is considered stable when:

- ≥5 consecutive RC runs produce zero contract violations
- No unexpected fallback artifacts are emitted
- Divergence stalls are explainable and <20% of RC runs
- Policy stability score shows consistent trend (no oscillation)

All verification criteria must be evaluated under a single immutable `governance-v1-lock` configuration (no schema, tuner, or policy changes during evaluation window).

The governance configuration is considered immutable during evaluation if the combined hash of the following files remains unchanged across the evaluation window:
- `tools/release_governor_policy.json` (tuner + divergence config)
- `tools/release_governor_safety_floors.json` (immutable floors)
- `tools/policy_drift_contract.schema.json` (contract schema)

### Baseline Hashes (captured at tag `governance-v1-lock`, 2026-04-13)

These are the canonical identity anchors for this lock. Any RC evaluation window must compare against these exact hashes to confirm the governance configuration is unchanged.

```json
{
  "algorithm": "SHA-256",
  "captured_at_tag": "governance-v1-lock",
  "captured_at_commit": "8de1d52",
  "files": {
    "tools/release_governor_policy.json":       "8D51CC44340D884542F6F7F75AE579CB153380F0E7B8ECBDD9F1E9B9842FAF6B",
    "tools/release_governor_safety_floors.json": "421153B8306A72F7A9F4B0D3C80E52287F5959C952B92FD76D9441D9A7A8D8D1",
    "tools/policy_drift_contract.schema.json":   "FC76FA2C11CFBD663C9AB4DA38FEB0F49FBCB4450B6B5217258AC7A00FE2D842"
  }
}
```

These hashes are a one-time capture tied to the tag. They must never be silently updated. Any change requires a new version tag (e.g., `governance-v1.1`).

**Hash mismatch behavior**: a mismatch does NOT fail CI. It fails **stability eligibility only** — the RC run is flagged as non-comparable and does not count toward the 5-run verification gate. CI diagnostics and artifact emission continue normally.

## Next Phase
- Observe 3–5 RC runs
- Validate contract stability
- Switch validationMode from observe → enforce after 3 clean runs
- Use policy_stability_score to gate auto-promotion readiness
