# Test Remediation Runner - Quick Reference

## Overview

The **Test Remediation Runner** automates Flutter integration test failure analysis and error report generation for AI-assisted patch creation.

## Files

- **`tools/remediate_tests.ps1`** — Main remediation script
- **`.remediation_config.json`** — Configuration (test paths, retry limits, etc.)
- **`.remediation_history.json`** — Auto-generated history of remediation attempts
- **`error_report.json`** — Auto-generated error report (paste into AI chat)

## Quick Start

### Run All Integration Tests

```powershell
.\tools\remediate_tests.ps1
```

### Run Specific Test File

```powershell
.\tools\remediate_tests.ps1 -TestFile "integration_test/app_tour_test.dart"
```

### Custom Max Attempts

```powershell
.\tools\remediate_tests.ps1 -TestFile "integration_test/payment_emulator_flow_test.dart" -MaxAttempts 3
```

## Remediation Workflow

1. **Run Script**
   ```powershell
   .\tools\remediate_tests.ps1 -TestFile "integration_test/app_tour_test.dart"
   ```

2. **Script Execution**
   - Runs `flutter test --machine` (JSON output)
   - Captures structured failure data
   - Extracts code context from failed test files
   - Generates `error_report.json`

3. **Review Error Report**
   - Open `error_report.json` (auto-generated in project root)
   - Or copy from terminal output (displayed at max attempts)

4. **Get Patch from AI**
   - Paste `error_report.json` content into your AI chat
   - Request a `.patch` file with suggested fixes
   - Save the patch as `remediation.patch`

5. **Review & Apply Patch**
   ```powershell
   # Review the patch first
   Get-Content remediation.patch

   # Apply if correct
   git apply remediation.patch
   ```

6. **Re-run Tests**
   ```powershell
   .\tools\remediate_tests.ps1 -TestFile "integration_test/app_tour_test.dart"
   ```

## Configuration

Edit `.remediation_config.json` to customize:

```json
{
  "testPaths": ["integration_test/", "test/"],
  "maxRetryAttempts": 5,
  "excludePatterns": ["test_helpers.dart", "*.g.dart"],
  "consecutiveFailures": 0
}
```

## Error Report Format

The auto-generated `error_report.json` contains:

```json
{
  "timestamp": "2026-07-03T14:32:15Z",
  "attemptNumber": 1,
  "totalFailures": 1,
  "testTarget": "integration_test/app_tour_test.dart",
  "failures": [
    {
      "testName": "Step-by-step walkthrough...",
      "error": "Exception: Widget not found...",
      "stackTrace": "...",
      "codeContext": "...",
      "fileLocation": "integration_test/app_tour_test.dart:45"
    }
  ]
}
```

## Exit Conditions

- ✅ **Pass:** All tests pass (exit code 0)
- ⏸️ **Max Attempts Reached:** After 5 failed attempts, script pauses for human review
- ❌ **Fatal Error:** Script exits if `flutter test` command fails

## Hints for AI Patch Requests

When pasting `error_report.json` into chat, include this prompt:

```
Please analyze this test failure and provide a git-ready patch file.
Focus on: [WebRTC signaling / UI state / specific error class]
The patch should fix the root cause, not just suppress the error.
```

## Future: GitHub Actions Integration

Once working locally, integrate into CI/CD by:

1. Copy script to `.github/workflows/test-remediation.yml`
2. Use GitHub Artifacts to download `error_report.json`
3. Add a "Retry with AI" workflow step

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Script won't run | Check execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned` |
| No `error_report.json` | Ensure `flutter test` runs successfully; check `test_output.log` |
| History not tracking | Verify write permissions to project root |
| Tests still failing after patch | Review patch diff; consider manual fixes if patch is incomplete |

## Support

For detailed help:
```powershell
Get-Help .\tools\remediate_tests.ps1 -Full
```
