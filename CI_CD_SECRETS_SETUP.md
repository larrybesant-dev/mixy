# GitHub Actions CI/CD Secrets Setup Guide

This guide walks through setting up permanent credentials for the MixVy E2E test suite in GitHub Actions.

## Required Secrets

### 1. Firebase Authentication Credentials

#### TEST_EMAIL
- **Type**: Repository Secret
- **Description**: Test user email for E2E test authentication
- **Value**: A valid Firebase Auth user email (e.g., `test-user@mixvy.local` or `ci-test@example.com`)
- **Security**: Use a dedicated test account (not production user)

#### TEST_PASSWORD
- **Type**: Repository Secret  
- **Description**: Password for the test user account
- **Value**: Strong password matching your Firebase Auth requirements
- **Security**: Store securely, rotate regularly (monthly recommended)

### 2. Firebase Configuration

#### FIREBASE_API_KEY (Optional but Recommended)
- **Type**: Repository Secret
- **Description**: Firebase Web API Key for direct Firebase Auth REST API calls
- **Value**: Found in Firebase Console → Project Settings → Web API Key
- **Security**: API keys are public-facing but restricted by AppCheck

#### FIREBASE_PROJECT_ID (Optional)
- **Type**: Repository Secret
- **Description**: Firebase Project ID
- **Value**: `mixvy-v2`
- **Security**: Safe to expose (needed by client code)

## Setup Instructions

### Step 1: Create Test User in Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select `mixvy-v2` project
3. Navigate to **Authentication** → **Users**
4. Click **Add user**
5. Enter:
   - **Email**: `test-ci@mixvy.local` (or your preferred test email)
   - **Password**: Generate strong password (15+ chars with mixed case, numbers, symbols)
6. Click **Create user**

### Step 2: Add Secrets to GitHub Repository

1. Go to your GitHub repository: https://github.com/larrybesant-dev/mixy
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions** (left sidebar)
4. Click **New repository secret** button

#### Add TEST_EMAIL Secret
- **Name**: `TEST_EMAIL`
- **Value**: `test-ci@mixvy.local` (the email you created)
- Click **Add secret**

#### Add TEST_PASSWORD Secret
- **Name**: `TEST_PASSWORD`
- **Value**: The password you generated
- Click **Add secret**

#### (Optional) Add FIREBASE_API_KEY Secret
- **Name**: `FIREBASE_API_KEY`
- **Value**: Your Firebase Web API Key
  - From Firebase Console: Project Settings → Web API Key
  - Looks like: `AIzaSyCqXHwQaMV1VvWxYnrAGqhGlx9S2K0MZZE`
- Click **Add secret**

### Step 3: Verify Secrets in Workflow

Check that secrets are referenced correctly in `.github/workflows/e2e-tests.yml`:

```yaml
env:
  TEST_EMAIL: ${{ secrets.TEST_EMAIL }}
  TEST_PASSWORD: ${{ secrets.TEST_PASSWORD }}
  FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}  # Optional
```

## Firestore Security Rules Considerations

The test credentials should only have access appropriate for E2E testing:

### Current Rules (from `firestore.rules`)
- Tests require authenticated user (`auth != null`)
- Default read/write permissions apply
- Adult-only rooms may be inaccessible without verification status

### Recommended Security Settings

1. **Keep AppCheck Disabled for CI/CD** (during testing phase)
   - Firebase Console → AppCheck
   - AppCheck enforces at runtime, blocking non-approved clients
   - While testing, have enforcement disabled for CI/CD runners

2. **Alternative**: Whitelist GitHub Actions IP
   - If AppCheck is enabled, you'll need to add GitHub Actions as an approved provider
   - This requires custom token validation in your backend

3. **Best Practice**: Separate test environment
   - Consider a dedicated Firebase project for CI/CD testing
   - Reduces risk to production data
   - Simplifies debugging

## Workflow Execution

Once secrets are configured:

1. **Push code** to `main` or `develop` branch
2. **Workflow automatically triggers** via GitHub Actions
3. **Tests authenticate** using TEST_EMAIL + TEST_PASSWORD
4. **Results** are published to workflow summary

### Test Execution Flow

```
1. Checkout code
   ↓
2. Install Node.js & dependencies
   ↓
3. Download Playwright browsers
   ↓
4. Authenticate (TEST_EMAIL/PASSWORD) ← Uses GitHub Secrets
   ↓
5. Run E2E tests (85 tests × 3 browsers)
   ↓
6. Generate reports
   ↓
7. Deploy to Firebase (if tests pass)
```

## Security Best Practices

### 1. Secret Rotation
- **Recommended**: Rotate TEST_PASSWORD monthly
- **Process**:
  1. Generate new password in Firebase Console
  2. Update `TEST_PASSWORD` secret in GitHub
  3. Disable old test account in Firebase

### 2. Access Control
- Only repository maintainers should access secrets
- GitHub Actions automatically masks secrets in logs
- Secrets are never printed in test output

### 3. Monitoring
- Check GitHub Actions logs for authentication failures
- Look for "Permission denied" or "Resource not accessible" errors
- Monitor test pass/fail rate in workflow runs

### 4. Scope Limitation
- Test account should NOT have admin privileges
- Restrict to read-only access if possible
- Use different test accounts for different test suites (optional)

## Troubleshooting

### Error: "HttpError: Resource not accessible by integration"

**Cause**: Firestore AppCheck enforcement blocking CI/CD runner

**Solution**:
1. Go to Firebase Console → AppCheck
2. Check if enforcement is enabled for REST APIs
3. Temporarily disable enforcement for testing
4. Re-enable after successful test run

### Error: "Authentication failed"

**Cause**: TEST_EMAIL or TEST_PASSWORD incorrect/expired

**Solution**:
1. Verify credentials work locally
2. Check test account exists in Firebase Console
3. Ensure password hasn't been reset
4. Update secrets in GitHub if changed

### Error: "Invalid Firebase API Key"

**Cause**: FIREBASE_API_KEY is incorrect or missing

**Solution**:
1. Get API key from Firebase Console → Settings
2. Ensure it's the **Web API Key**, not Server Key
3. Update FIREBASE_API_KEY secret in GitHub

## Firebase Console Access

- **Firebase Console**: https://console.firebase.google.com
- **Project**: mixvy-v2
- **Authentication**: https://console.firebase.google.com/project/mixvy-v2/authentication/users
- **AppCheck**: https://console.firebase.google.com/project/mixvy-v2/appcheck

## Related Files

- Workflow file: [`.github/workflows/e2e-tests.yml`](.github/workflows/e2e-tests.yml)
- Auth utilities: [`e2e/utils/auth.ts`](e2e/utils/auth.ts)
- Test suite: [`e2e/`](e2e/)

## Next Steps

1. ✅ Create test user in Firebase
2. ✅ Add secrets to GitHub Actions
3. ✅ Push code to trigger workflow
4. ✅ Monitor first test run
5. ✅ Adjust settings as needed
