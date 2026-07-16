# E2E Test Authentication Fallback Strategy

This document explains how the MixVy E2E test suite handles authentication through multiple fallback methods.

## Authentication Methods (Priority Order)

### 1. LocalStorage Check (Fast Path)
**Status**: ✅ Currently Authenticated

If the test discovers an existing Firebase Auth token in localStorage, it skips authentication entirely.

```typescript
const isAlreadyAuth = await page.evaluate(() => {
  const firebaseAuth = localStorage.getItem('firebase:authUser:mixvy-v2');
  return !!firebaseAuth;
});
```

**Benefit**: Skips authentication if session already exists (speeds up repeated runs)

---

### 2. Email/Password Form Authentication
**Status**: ⚙️ Primary Authentication Method

The first attempt to authenticate uses the standard login form in the MixVy app.

**Process**:
1. Navigate to `/auth` page
2. Look for email input field
3. Fill in TEST_EMAIL from environment
4. Fill in password from TEST_PASSWORD
5. Click login button
6. Wait for navigation to complete
7. Verify localStorage contains Firebase auth token

**When it works**: ✅
- Flutter web app has standard login form
- Email/password login is enabled in Firebase
- No special app configuration needed

**When it fails**: ❌
- Social login only (no email/password)
- Custom authentication UI
- Login form hidden or inaccessible
- Test account not registered

**Fallback**: Proceeds to method 3

---

### 3. Firebase Auth REST API
**Status**: 🔑 Server-Side Authentication

If the UI form authentication fails, tests attempt direct Firebase API calls to authenticate.

**Process**:
1. Make HTTP POST to Firebase Identity Toolkit endpoint
2. Send credentials: `{ email, password, returnSecureToken: true }`
3. Parse response to get `idToken` and `localId`
4. Manually inject auth tokens into browser localStorage
5. Simulate Firebase Auth session creation

**Endpoint**:
```
POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}
```

**When it works**: ✅
- Firebase Auth is configured
- Email/password provider is enabled
- Test credentials are valid
- FIREBASE_API_KEY secret is configured

**When it fails**: ❌
- Firebase API key is incorrect/missing
- Credentials are invalid
- Firebase Auth is not set up
- API rate limiting (too many attempts)

**Why this works**: Bypasses UI entirely, directly creates auth session

**Fallback**: Proceeds to method 4

---

### 4. Guest/Anonymous Access
**Status**: 🌐 Public Access Fallback

If authenticated access fails, tests attempt to access the app as a guest.

**Process**:
1. Look for "Guest", "GUEST", or "Enter as Guest" buttons
2. Click guest access button
3. Wait for app to load in guest mode

**When it works**: ✅
- App has guest/anonymous access option
- Some features work without authentication
- Can test public pages/rooms

**When it fails**: ❌
- App requires authentication for all features
- No guest access available
- All content is behind authentication

**Use case**: Testing public-facing features when auth is unavailable

---

## Complete Authentication Flow Diagram

```
Start Test
    ↓
Check localStorage for existing auth
    ├─ YES → Skip auth, proceed ✅
    └─ NO → Continue
    ↓
Attempt Email/Password Form Authentication
    ├─ SUCCESS → Auth token received ✅
    └─ FAILURE → Continue
    ↓
Attempt Firebase REST API Authentication  
    ├─ SUCCESS → Auth token injected ✅
    └─ FAILURE → Continue
    ↓
Attempt Guest/Anonymous Access
    ├─ SUCCESS → Guest session created ✅
    └─ FAILURE → Warn and continue
    ↓
Test Executes
```

---

## Configuration via Environment Variables

### TEST_EMAIL
- **Purpose**: Test user email for all auth methods
- **Default**: `test@example.com` (if not set)
- **Set in GitHub Actions**: `secrets.TEST_EMAIL`
- **Local testing**: `export TEST_EMAIL=test-user@example.com`

### TEST_PASSWORD
- **Purpose**: Test user password for forms and REST API
- **Default**: `Test123456!` (if not set)
- **Set in GitHub Actions**: `secrets.TEST_PASSWORD`
- **Local testing**: `export TEST_PASSWORD=MySecurePassword123!`

### FIREBASE_API_KEY (Optional)
- **Purpose**: Firebase Web API Key for REST API authentication
- **Default**: Hardcoded public key (not recommended for production)
- **Set in GitHub Actions**: `secrets.FIREBASE_API_KEY`
- **Local testing**: `export FIREBASE_API_KEY=AIzaSy...`

---

## Monitoring Authentication Success

### Success Indicators

Each successful authentication method logs a message:

```typescript
// LocalStorage auth
console.log('✓ User already authenticated via localStorage');

// Form auth
console.log('✓ Authenticated via email/password form');

// REST API auth
console.log('✓ Authenticated via Firebase REST API');

// Guest access
console.log('✓ Accessed as guest');
```

### Failure Indicators

If all methods fail:

```typescript
console.warn('⚠ Could not authenticate - tests may require authentication');
```

### Checking Test Logs

In GitHub Actions:
1. Go to workflow run
2. Click on a failed browser job
3. Look for authentication messages in logs
4. Search for `✓` (success) or `⚠` (warning) symbols

---

## Troubleshooting Guide

### "Could not authenticate - tests may require authentication"

**Problem**: All 4 authentication methods failed

**Solutions**:

#### Check TEST_EMAIL and TEST_PASSWORD
```bash
# Locally
export TEST_EMAIL="your-test-email@example.com"
export TEST_PASSWORD="your-test-password"
npm run test:e2e
```

#### Verify Test Account Exists
1. Firebase Console → Authentication → Users
2. Search for TEST_EMAIL
3. Confirm account status is "Active"
4. Reset password if needed

#### Check Firebase REST API
```bash
# Test Firebase Auth directly (replace with your details)
curl -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSy..." \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","returnSecureToken":true}'
```

#### Check LocalStorage Persistence
```javascript
// Run in browser console on app
console.log(localStorage.getItem('firebase:authUser:mixvy-v2'));
```

---

## Advanced: Implementing Custom Auth Methods

To add a new authentication method, add a new `tryXxxAuth()` function to `e2e/utils/auth.ts`:

```typescript
async function tryCustomAuth(page: Page, email: string, password: string): Promise<boolean> {
  try {
    // Your custom auth logic here
    // Return true on success, false on failure
    
    // Example: Token-based API
    const response = await page.request.post('/api/auth/login', {
      data: { email, password }
    });
    
    if (response.ok()) {
      const { token } = await response.json();
      // Store token appropriately
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
```

Then add it to the main authentication flow in priority order:

```typescript
// In authenticateTestUser()
const customSuccess = await tryCustomAuth(page, testEmail, testPassword);
if (customSuccess) {
  console.log('✓ Authenticated via custom method');
  return;
}
```

---

## Performance Implications

### Auth Timing
- **LocalStorage check**: ~10ms (fastest)
- **Form auth**: ~2-3s (moderate)
- **REST API auth**: ~1-2s (moderate)
- **Guest access**: ~500ms (fast)

### Total Impact
- With existing auth: **~10ms overhead** (just check)
- First run (form auth): **~2-3s** (one-time)
- REST API fallback: **~1-2s** (if form fails)

### Optimization
- Consider auth persistence between test runs
- Reuse browser session when possible
- Cache auth tokens locally during development

---

## Security Considerations

### What's Stored Locally
When authentication succeeds, localStorage contains:
- User UID
- Email address
- Access token (expires in ~1 hour)
- Metadata (creation time, etc.)

### What's NOT Stored
- Passwords (only used during auth request)
- Sensitive user data
- Admin credentials

### Best Practices
- Use dedicated test account (not production user)
- Rotate TEST_PASSWORD monthly
- Never commit credentials to git
- Monitor test account activity in Firebase
- Use GitHub Secrets for all credentials

---

## Related Documentation

- [GitHub Actions Secrets Setup](CI_CD_SECRETS_SETUP.md)
- [Playwright Documentation](https://playwright.dev)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Test Suite](e2e/)
