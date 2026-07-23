# Staging Operational Gate Template

Date:
Environment:
App Version:
Operator:

## Summary Verdict
- Presence churn: PASS / FAIL
- Room churn: PASS / FAIL
- Feed collapse simulation: PASS / FAIL
- Backend failure injection: PASS / FAIL
- Scale probe: PASS / FAIL
- Final recommendation: HOLD / STAGED ROLLOUT / PROCEED

## Presence Churn
| Scenario | Result | Max Latency (s) | Ghost State | Notes | Evidence |
|---|---|---:|---|---|---|
| Hard kill |  |  |  |  |  |
| Dual-device integrity |  |  |  |  |  |
| Airplane mode |  |  |  |  |  |
| Wifi to LTE switch |  |  |  |  |  |
| Reconnect spam |  |  |  |  |  |

## Room Churn
| Scenario | Result | Member Drift | Orphans | Authority Converged | Notes | Evidence |
|---|---|---:|---|---|---|---|
| 100 rapid creates |  |  |  |  |  |  |
| Rapid joins/leaves |  |  |  |  |  |  |
| Host disconnect mid-stream |  |  |  |  |  |  |
| Mass reconnect |  |  |  |  |  |  |

## Feed Collapse Simulation
| Scenario | Result | Fallback Visible | Crash/Spinner | Invariant Intact | Notes | Evidence |
|---|---|---|---|---|---|---|
| No discoverable rooms |  |  |  |  |  |  |
| No warm rooms |  |  |  |  |  |  |
| Remote Config unavailable |  |  |  |  |  |  |
| Malformed timestamps |  |  |  |  |  |  |

## Backend Failure Injection
| Scenario | Result | Graceful Degradation | Retry Safe | Telemetry Seen | Notes | Evidence |
|---|---|---|---|---|---|---|
| Firestore denied |  |  |  |  |  |  |
| RTDB unavailable |  |  |  |  |  |  |
| Callable timeout |  |  |  |  |  |  |
| Delayed bridge sync |  |  |  |  |  |  |

## Scale Probe
| Volume | Snapshot Latency | Classification Time | Rebuild Pressure | Memory Churn | Verdict | Notes |
|---|---:|---:|---|---|---|---|
| 10 rooms |  |  |  |  |  |  |
| 100 rooms |  |  |  |  |  |  |
| 1000 rooms |  |  |  |  |  |  |

## Blocking Findings
- 

## Follow-up Tickets
- 
