$score = Get-Content tools/reports/policy_drift_score.json | ConvertFrom-Json

Write-Host "=== POLICY DRIFT SCORE SUMMARY ===" -ForegroundColor Cyan
Write-Host "DriftScore: $($score.summary.driftScore) / 100" -ForegroundColor Yellow
Write-Host "Tier: $($score.summary.tier)" -ForegroundColor Green
Write-Host "Recommendation: $($score.summary.recommendation.action)" -ForegroundColor Magenta
Write-Host ""

Write-Host "=== HIERARCHICAL COMPONENTS ===" -ForegroundColor Cyan
Write-Host "S (Primary - Structural Similarity): $($score.components.structuralSimilarity.value)" -ForegroundColor Yellow
Write-Host "  Role: $($score.components.structuralSimilarity.role)"
Write-Host "  Meaning: $($score.components.structuralSimilarity.interpretation)"
Write-Host ""

Write-Host "T (Secondary - Boundary Fragmentation): $($score.components.boundaryFragmentation.normalizedValue)" -ForegroundColor Yellow
Write-Host "  Raw: $($score.components.boundaryFragmentation.rawValue) / $($score.components.boundaryFragmentation.sweepSize)"
Write-Host "  Role: $($score.components.boundaryFragmentation.role)"
Write-Host "  Meaning: $($score.components.boundaryFragmentation.interpretation)"
Write-Host ""

Write-Host "E (Tertiary - Temporal Drift): $($score.components.temporalDrift.normalizedValue)" -ForegroundColor Yellow
Write-Host "  Raw: $($score.components.temporalDrift.rawValue) / $($score.components.temporalDrift.maxHistoryDepth)"
Write-Host "  Role: $($score.components.temporalDrift.role)"
Write-Host "  Meaning: $($score.components.temporalDrift.interpretation)"
Write-Host ""

Write-Host "=== FORMULA BREAKDOWN ===" -ForegroundColor Cyan
Write-Host "DriftScore = 100(1-S) + 25T + 15E"
Write-Host "            = 100($([math]::Round(1-$($score.components.structuralSimilarity.value),2))) + 25($([math]::Round($($score.components.boundaryFragmentation.normalizedValue),3))) + 15($([math]::Round($($score.components.temporalDrift.normalizedValue),3)))"
Write-Host "            = $([math]::Round($($score.breakdown.componentContribution.structuralTerm),2)) + $([math]::Round($($score.breakdown.componentContribution.boundaryTerm),2)) + $([math]::Round($($score.breakdown.componentContribution.temporalTerm),2))"
Write-Host "            = $($score.summary.driftScore)" -ForegroundColor Green
Write-Host ""

Write-Host "=== GATING DECISION ===" -ForegroundColor Cyan
Write-Host "Hard Fail Condition: Jaccard < 0.7 -> $($score.components.structuralSimilarity.value -lt 0.7)"
Write-Host "Soft Fail Condition: DriftScore > 45 -> $($score.summary.driftScore -gt 45)"
Write-Host "Final Tier: $($score.summary.tier)" -ForegroundColor Green
Write-Host "Recommendation: $($score.summary.recommendation.action)"
Write-Host ""
Write-Host $score.summary.recommendation.explanation
