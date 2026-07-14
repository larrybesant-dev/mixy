# Test Account Creation Scripts

This directory contains utility scripts for creating and managing test accounts for MixVy development and QA.

## Quick Start

### Create a Single Test Account

```bash
cd functions
node scripts/create-test-accounts.js
```

Output:
```
🚀 MixVy Test Account Creator
Creating 1 test account(s)...
[1/1] Creating testuser-1721002800000-1@mixvy.dev... ✓

📊 Results Summary
────────────────────────────────────────────────────────
✓ Successful: 1/1
✗ Failed: 0/1

📋 Test Accounts Created
────────────────────────────────────────────────────────

[1] testuser-1721002800000-1@mixvy.dev
    UID:      a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
    Password: TestPassword123!
    Status:   Ready for testing

🔗 Login URL: https://mixvy-v2.web.app/auth

✅ Process complete
```

### Create Multiple Test Accounts

```bash
# Create 5 test accounts
node scripts/create-test-accounts.js --count=5

# Create 10 accounts with custom email prefix
node scripts/create-test-accounts.js --count=10 --prefix=qa-tester
```

## Usage Options

| Option | Example | Description |
|--------|---------|-------------|
| `--count` | `--count=5` | Number of accounts to create (default: 1) |
| `--prefix` | `--prefix=qa-user` | Email prefix (default: testuser) |

### Email Format

Generated emails follow the pattern:
```
{prefix}-{timestamp}-{index}@mixvy.dev
```

Example with default settings:
- `testuser-1721002800000-1@mixvy.dev`
- `testuser-1721002800000-2@mixvy.dev`
- `testuser-1721002800000-3@mixvy.dev`

## Prerequisites

### 1. Firebase Admin SDK Credentials

The script requires Firebase Admin SDK credentials. Set up one of the following:

**Option A: Service Account File (Development)**
```bash
# Place service account JSON in functions directory
functions/service-account-key.json

# Or set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
```

**Option B: Firebase CLI Emulator**
```bash
# Works when running from a Firebase Hosting context
# The script will auto-detect credentials
```

### 2. Node.js Dependencies

Ensure `firebase-admin` is installed:
```bash
cd functions
npm install firebase-admin
```

## Test Account Details

Each created test account:
- ✓ Has a verified email address
- ✓ Password: `TestPassword123!`
- ✓ Starting coin balance: 50 coins
- ✓ Membership level: Free
- ✓ Tagged as `testAccount: true` in Firestore
- ✓ Tagged as `betaTester: true` for beta features
- ✓ Username: Derived from email prefix
- ✓ Firestore document created at `/users/{uid}`

## Manual Testing Workflow

### 1. Create Test Accounts
```bash
node scripts/create-test-accounts.js --count=3
```

### 2. Copy Email and Password
From the output, note the email and password.

### 3. Log In to App
1. Go to https://mixvy-v2.web.app/auth
2. Click "SIGN IN"
3. Enter email and password
4. Verify successful login and navigation to home screen

### 4. Verify AppCheck (Network Tab)
1. Right-click → Inspect → Network tab
2. Look for requests to `identitytoolkit.googleapis.com`
3. Confirm NO 400 responses
4. Verify successful Firestore document creation

### 5. Test App Features
- Room discovery
- Room entry (tests the AppCheck/Agora token flow)
- Messaging
- Profile updates
- Payments (coins)

## Troubleshooting

### "Firebase Admin SDK not initialized"
**Solution**: Ensure `GOOGLE_APPLICATION_CREDENTIALS` env var is set:
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
node scripts/create-test-accounts.js
```

### "Email already exists"
**Solution**: The script generates unique emails with timestamps, so this shouldn't occur. If it does:
1. Delete the test user from Firebase Console
2. Or use a different `--prefix`

### "Permission denied"
**Solution**: Check that your service account has these permissions:
- `roles/firebase.admin` or equivalent
- Firebase Auth Admin
- Firestore Editor

### "Connection timeout"
**Solution**: 
1. Check internet connection
2. Verify Firebase project ID is correct in script
3. Ensure you're not rate-limited (Firebase has request quotas)

## Firebase Console Cleanup

To delete test accounts created with this script:

1. Go to Firebase Console → Authentication
2. Find accounts with email `testuser-*@mixvy.dev`
3. Click delete icon
4. Confirm deletion

Or use the Firebase CLI:
```bash
firebase auth:delete testuser-1721002800000-1@mixvy.dev
```

## Integration with CI/CD

For automated testing in pipelines:

```bash
#!/bin/bash
# scripts/setup-test-environment.sh

# Create test accounts for integration tests
export GOOGLE_APPLICATION_CREDENTIALS="${PWD}/ci-service-account.json"
cd functions
node scripts/create-test-accounts.js --count=5 --prefix=ci-test

# Run integration tests
cd ..
flutter test integration_test/auth_appcheck_integration_test.dart
```

## Security Notes

⚠️ **Do NOT use in production:**
- Test accounts are tagged `testAccount: true`
- Firestore rules can filter these out
- Never deploy test account creation to production

⚠️ **Do NOT commit credentials:**
- Service account JSON files should NOT be committed to git
- Add to `.gitignore`: `functions/service-account-key.json`
- Use environment variables or secure vaults in CI/CD

## Related Documentation

- [Authentication Flow Documentation](../AUTHENTICATION_FLOW.md)
- [Integration Tests](../integration_test/auth_appcheck_integration_test.dart)
- [Firebase Admin SDK](https://firebase.google.com/docs/database/admin/start)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

---

**Created**: 2026-07-14  
**Last Updated**: 2026-07-14  
**Purpose**: Support manual testing and QA for MixVy authentication and AppCheck flows
