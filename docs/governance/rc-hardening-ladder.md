# RC Hardening Ladder

Governance lock: `governance-v1-lock`  
Burn-in window: 6 runs (`burnInRcCount: 6`)  
Short tuner window: 10 runs | Baseline tuner window: 30 runs  

This ladder defines when the governance system transitions from "locally green" to "production-trustworthy." Each phase has a specific question it answers and a go/no-go condition. Do not skip phases or collapse them under time pressure.

---

## Phase 1 — Signal Stability (RC-1 → RC-3)

**Question answered:** Does the observability pipeline produce consistent, deterministic structural output?

**What to observe:**
- All 3 signals present across every run
- Zero contract violations
- Zero hash mismatches
- `artifact_mode: primary` in every run

**Go condition:** RC-1 through RC-3 produce identical categorical signal output with zero anomalies.  
**No-go condition:** Any contract failure, hash mismatch, or missing artifact.

**Current status:** ✅ COMPLETE — RC-1, RC-2, RC-3 all clean.

---

## Phase 2 — Repeatability Confirmation (RC-4 → RC-5)

**Question answered:** Is Phase 1 stability reproducible, or was it initialization artifact?

**What to observe:**
- Same 3-signal profile as RC-1 through RC-3
- No new fields appearing or disappearing in artifacts
- `inBurnInFreeze: true` consistently (expected — burn-in window is 6 runs)

**Go condition:** RC-4 and RC-5 match RC-1 through RC-3 profile with no deviations.  
**No-go condition:** Any categorical signal change from Phase 1 baseline.

**Current status:** ⏳ IN PROGRESS

---

## Phase 3 — Burn-in Boundary (RC-6)

**Question answered:** Does the tuner exit burn-in cleanly, and does behavior change as designed?

**What to observe:**
- `inBurnInFreeze` transitions from `true` to `false` (or remains `true` if early-exit threshold not met)
- `recommendationState` may change from `burn_in` to `stable | drifting | unstable`
- `policy_divergence_score` becomes meaningful for the first time
- `policy_stability_score` starts accumulating real signal

**Go condition:** Burn-in exits (or documented holdover reason exists), tuner emits a non-burn_in recommendation state, all artifacts still `artifact_mode: primary`.  
**No-go condition:** Fallback activation, contract failure, or tuner emitting `artifact_mode: fallback`.

**Critical check:** Read raw `proposed_thresholds.json` at RC-6. First real tuner recommendation appears here.

---

## Phase 4 — Active Tuner Observation (RC-7 → RC-9)

**Question answered:** Does the tuner produce stable recommendations under normal RC conditions? Is divergence scoring behaving rationally?

**What to observe:**
- `recommendationType` stability (should not oscillate between `hold | tune | stall_and_review` without cause)
- `policy_divergence_score` — should be low and stable under unchanged conditions
- `divergence_classification` — expect `transient` at most; `structural` is a signal to investigate
- `policy_stability_score` — should trend upward or hold; oscillation is a red flag
- Whether any runs trigger `stall_and_review` (if yes: investigate before proceeding)

**Go condition:** RC-7 through RC-9 show consistent `recommendationType`, no `structural` divergence classification, and `policy_stability_score` not declining.  
**No-go condition:** `stall_and_review` appearing repeatedly, oscillating recommendation type, or `policy_stability_score` < 0.5 and declining.

---

## Phase 5 — Stability Score Validation (RC-10)

**Question answered:** Is the `policy_stability_score` meaningful and trending toward a value that can gate promotion decisions?

**What to observe:**
- `policy_stability_score` at RC-10: should be ≥ 0.7 under clean conditions
- No `structural` divergence classifications in Phases 3–4
- No fallback artifact usage in Phases 3–4
- Approval system untouched (no manual promotions during observation)

**Go condition (production-trustworthy threshold):**
- ≥ 5 consecutive eligible runs with zero contract violations ← from Verification Criteria
- Zero unexpected fallback artifacts across Phases 3–4
- Divergence stalls explaining < 20% of runs
- `policy_stability_score ≥ 0.7` at RC-10
- All under unchanged `governance-v1-lock` configuration (hash match confirmed)

**No-go condition:** Any of the above thresholds unmet.

---

## Phase 6 — Enforcement Activation (Post RC-10)

**Triggered only when Phase 5 go-condition is fully met.**

**Actions (in order):**
1. Change `"validationMode": "observe"` → `"validationMode": "enforce"` in `tools/release_governor_policy.json`
2. Update CI `validate_policy_drift_contract` step: change `-ValidationMode observe` → `-ValidationMode enforce`
3. Remove `continue-on-error: true` from the validation step in CI
4. Recompute and update baseline hashes in `docs/governance/governance-v1-lock.md`
5. Commit + tag: `governance-v1.1` (policy change requires new tag per lock rules)

---

## Quick Reference: What Changes at Each Boundary

| RC Boundary | Key change in system behavior |
|---|---|
| RC-1 → RC-3 | Observability pipeline proven |
| RC-4 → RC-5 | Repeatability proven |
| RC-6 | Burn-in lifts, tuner becomes active |
| RC-7 → RC-9 | First real divergence + stability scoring data |
| RC-10 | Stability score reaches meaningful threshold |
| Post-RC-10 | `validationMode: observe` → `enforce` |

---

## Observation Rule (applies to all phases)

No tuning changes, schema edits, threshold adjustments, or policy modifications during the ladder. Any change resets the eligibility window and requires a new version tag before resuming.
