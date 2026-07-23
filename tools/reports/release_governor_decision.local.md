# Release Governor Decision

- GeneratedAtUtc: 2026-04-13T13:22:34.5700693Z
- GovernanceDecision: ALLOW
- PolicyVersion: release_governor_policy_v1
- RunCount: 1
- RecentWindowSize: 3
- RecentSlope: 0
- RecentStdDev: 0
- RecentVolatilityBand: stable
- PreviousVolatilityBand: unknown
- VarianceIncreasePercent: 0

## Rule Outcomes

| Rule | Severity | Triggered | Metric | MessageModel |
|---|---|---:|---|---|
| GV-H1 | hard | False | latestVerdict=PASS | Block when latest release verdict is FAIL. |
| GV-H2 | hard | False | recentSlope=0 threshold=-2 | Block on sustained negative confidence slope in recent window. |
| GV-H3 | hard | False | previousBand=unknown recentBand=stable | Block on volatility escalation from stable to moderate/volatile. |
| GV-H4 | hard | False | consecutiveLow=0 threshold=2 limitScore=75 | Block on consecutive low-confidence runs. |
| GV-W1 | warning | False | varianceIncreasePct=0 threshold=30 | Warn when confidence variance increases significantly vs baseline window. |
| GV-W2 | warning | False | delta=0 threshold=-10 latestTierPass=True | Warn when confidence drops despite Tier 0 and Tier 1 passing. |
| GV-I1 | info | True | runCount=1 minRequired=5 | Trend hard-rules are observation-only until minimum sample size is reached. |
