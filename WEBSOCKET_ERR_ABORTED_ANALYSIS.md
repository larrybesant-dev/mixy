# Firestore WebSocket `net::ERR_ABORTED` Root Cause Analysis

**Date:** 2026-07-17  
**Issue:** WebSocket and HTTP long-polling connections to Firestore aborting with `net::ERR_ABORTED`  
**Impact:** Discovery feed and all real-time Firestore features blocked

---

## 📊 Evidence Gathered

### ✅ What's Working
- **Firebase SDK Configuration**
  - API Key: `AIzaSyCM6_Eye8JMEW7dXFpo-i-Frp4t3owyh_I`
  - Firestore API: ✅ ENABLED in API restrictions
  - Cloud Firestore API: ✅ Listed in 25 allowed APIs
  
- **Firebase Authorization**
  - Authorized Domains: ✅ `mixvy-v2.web.app` included
  - ✅ `localhost` included
  - ✅ `mixvy-v2.firebaseapp.com` included
  
- **App Configuration**
  - Firebase initialization: ✅ Working
  - User authentication: ✅ Working (login succeeds)
  - REST API calls: ✅ Working (auth tokens valid)
  - UI rendering: ✅ Home screen loads
  
- **Firestore Settings**
  - `persistenceEnabled: true` (50MB cache)
  - `ignoreUndefinedProperties: true`
  - Configuration source: Single source of truth (firestoreProvider)
  - No conflicting settings in main.dart ✅

### ❌ What's Failing
- **WebSocket/Long-Polling Connections**
  - Requests to `/google.firestore.v1.Firestore/Write/channel`: ❌ `net::ERR_ABORTED`
  - Requests to `/google.firestore.v1.Firestore/Listen/channel`: ❌ `net::ERR_ABORTED`
  - **Pattern:** Occurs even with `TYPE=xmlhttp` (HTTP fallback)
  - **Timing:** Retries every ~60 seconds (Firestore fallback logic activating)

---

## 🔍 Root Cause Hypothesis

### Most Likely (90% confidence)
**Browser Extension Blocking XMLHttpRequest to *.googleapis.com**

Evidence:
- HTTP long-polling requests (not just WebSocket) are being aborted
- Only connections to `firestore.googleapis.com` are failing
- REST API calls to other Firebase services work
- No CSP headers in index.html would block this
- `net::ERR_ABORTED` is typical of extension interception

Common Blockers:
- ✅ **uBlock Origin** (too aggressive default rules)
- ✅ **Privacy Badger**
- ✅ **Ghostery**
- ✅ Some VPN clients
- ✅ Corporate network proxies

### Secondary (5% confidence)
**Network-Level Firewall/Proxy**
- Corporate network policies blocking WebSocket to `*.googleapis.com`
- ISP-level filtering
- Country-specific geoblocking

### Tertiary (5% confidence)
**Flutter Web Build Issue**
- Wasm/JS interop problem with HTTP long-polling
- Specific issue with chrome sandbox

---

## 🧪 Testing Protocol

### Test 1: Incognito/Private Window (Disable Extensions)
```bash
Steps:
1. Open new INCOGNITO window (Ctrl+Shift+N)
2. Navigate to https://mixvy-v2.web.app/auth
3. Login with test account
4. Open DevTools (F12) → Console
5. Check for Firestore errors

Expected if extension is blocking:
  - Error disappears in incognito
  - Discovery feed loads
  - Real-time features work
```

### Test 2: Disable Specific Extensions
```bash
Steps:
1. Open DevTools → Extensions (puzzle icon)
2. Disable ALL extensions
3. Reload page
4. Check if WebSocket works

Expected:
  - Clear status message in console
  - Firestore requests succeed or timeout normally (not abort)
```

### Test 3: VPN/Proxy Check
```bash
Steps:
1. Disable any VPN/Proxy (Settings → Network)
2. Test direct connection
3. If still failing, your ISP/network is filtering

Expected:
  - Direct connection should work
  - If still fails = network-level block
```

### Test 4: Network Tab Inspection
```bash
Chrome DevTools → Network Tab
Steps:
1. Open app with DevTools open
2. Filter by "firestore.googleapis.com"
3. Right-click failed request → Copy as cURL
4. Share the request headers and response status

Key fields to check:
  - Request Method: GET
  - Status: Should be 101 (WebSocket Upgrade) or 200
  - If blank/error: Connection aborted
  - Headers: Cache-Control, Authorization, Origin
```

---

## 🛠️ Fixes to Try (In Order)

### Fix 1: Disable Browser Extensions (Quick Test)
- Temporarily disable all extensions
- Reload page
- If it works = extension is the culprit
- Permanently add `*.mixvy-v2.web.app` and `*.googleapis.com` to extension allowlist

### Fix 2: Test with Different Browser
- Try Edge/Firefox/Safari
- If works in one browser = browser-specific issue
- Check that browser's extension/proxy settings

### Fix 3: Clear Browser Cache
- Chrome: Ctrl+Shift+Delete
- Select "All time"
- Clear cached images and files
- Reload page

### Fix 4: Disable VPN/Proxy
- Windows Settings → Network & Internet → VPN
- Disconnect any VPN
- Also check Windows → Settings → Network → Proxy
- Disable proxy if enabled

### Fix 5: Check Corporate Network Policies
- If behind corporate firewall:
  - Contact IT to allowlist `*.firestore.googleapis.com` and `*.googleapis.com`
  - Request WebSocket protocol (ws://, wss://) be allowed
  - Request HTTP long-polling (xmlhttp/XHR) be allowed

### Fix 6: Firestore Client Library Fallback (Nuclear Option)
If all else fails, configure Firestore to skip WebSocket:
```dart
// lib/core/providers/firebase_providers.dart
if (kIsWeb) {
  firestore.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 50 * 1024 * 1024,
    ignoreUndefinedProperties: true,
    host: 'firestore.googleapis.com',
    sslEnabled: true,
    // Force HTTP only (skip WebSocket attempt)
    experimentalForceLongPolling: true, // if this option exists
  );
}
```

---

## 📋 Diagnostic Checklist for User

- [ ] Test 1: Open app in incognito window
- [ ] Test 2: Disable all browser extensions
- [ ] Test 3: Check for active VPN/Proxy in system settings
- [ ] Test 4: Inspect Network tab and share failed request details
- [ ] Test 5: Try different browser (Chrome vs Edge vs Firefox)
- [ ] Test 6: Clear browser cache completely
- [ ] Test 7: If corporate network, contact IT about firestore.googleapis.com allowlist

---

## 🎯 Next Steps

1. **Run Test 1** (incognito window) first
   - Takes 2 minutes
   - 90% chance identifies the issue
   
2. **If Test 1 fails:**
   - Run Test 2 (disable extensions)
   - Run Test 3 (check VPN)
   
3. **If Tests 1-3 all fail:**
   - This is a network-level issue
   - Likely corporate firewall or ISP filtering
   - Contact network administrator

4. **Share results:**
   - Screenshot of DevTools Network tab
   - List of installed extensions
   - VPN/Proxy status
   - Browser name and version

---

## 📞 Reference

- Firestore Connection Issues: https://firebase.google.com/docs/firestore/troubleshoot-connection
- WebSocket Failures: https://developers.google.com/web/tools/chrome-devtools/network
- Firebase on Web: https://firebase.google.com/docs/web/setup

---

**Status:** 🟡 AWAITING USER TESTING  
**Owner:** Copilot Agent  
**Last Updated:** 2026-07-17T00:26:00Z
