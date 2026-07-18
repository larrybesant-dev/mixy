# Firestore WebSocket Debugging Checklist

## 🔴 Current Status
- ✅ Authentication works
- ✅ App UI renders
- ❌ Real-time listeners abort with `net::ERR_ABORTED`
- ❌ Discovery feed can't load

## 🧪 Debugging Steps (In Order)

### **Step 1: API Key Verification** (5 min)

**Location:** https://console.cloud.google.com/apis/credentials

1. Find API key: `AIzaSyCM6_Eye8JMEW7dXFpo-i-Frp4t3owyh_I`
2. Click to edit
3. Check **API restrictions**:
   - [ ] "Cloud Firestore API" is listed ✅
   - [ ] "Cloud Datastore API" is listed ✅
   - [ ] If restricted, these MUST be allowed
4. Check **Application restrictions**:
   - [ ] Type is "Web applications"
   - [ ] `mixvy-v2.web.app` is in the list
   - [ ] `localhost` is in the list (for testing)

**Action if Missing:**
- Add `Cloud Firestore API` to API restrictions
- Add domain to Application restrictions
- Save changes
- Wait 5 minutes for propagation
- Test again

---

### **Step 2: Firebase Console Domain Allowlist** (3 min)

**Location:** https://console.firebase.google.com/project/mixvy-v2/authentication/settings

1. Click "Settings" tab
2. Scroll to "Authorized Domains"
3. Verify list includes:
   - [ ] `mixvy-v2.web.app` ✅
   - [ ] `mixvy-v2.firebaseapp.com` ✅
   - [ ] `localhost` (if testing locally)
4. If missing, click "Add domain" and add them

**Note:** This is for Auth, but WebSocket failures suggest a related domain issue

---

### **Step 3: Browser Network Inspection** (10 min)

**Steps:**
1. Open Browser DevTools: **F12**
2. Go to **Network** tab
3. Filter: type `Listen` in the search box
4. Reload the app page
5. Look for requests to `/Firestore/Listen/channel`
6. Right-click on a failed request → **Copy → Copy as cURL**

**Share with Debugging Info:**
```
Request URL: [paste from Network tab]
Request Method: [GET/POST]
Status Code: [should be 101 or 200, if aborted it's blank]
Response Headers:
  - Content-Type: [paste]
  - Access-Control-Allow-Origin: [paste]
Error Message: [paste the full error text]
```

---

### **Step 4: Browser Console Check** (5 min)

**Steps:**
1. Open DevTools: **F12**
2. Go to **Console** tab
3. Reload the page
4. Look for:
   - Red error messages starting with "Firestore" or "WebSocket"
   - CORS errors (show `Access-Control-*` headers)
   - CSP violations (show `Content-Security-Policy`)
   - Any error stack traces

**Action if Found:**
- Screenshot or copy the exact error message
- It often contains the root cause

---

### **Step 5: Incognito/Private Window Test** (3 min)

**Purpose:** Rule out browser extensions blocking connections

**Steps:**
1. Open new **Incognito** window (Ctrl+Shift+N on Windows)
2. Navigate to https://mixvy-v2.web.app/auth
3. Login with: `test_a_prod@example.com` / `ProdTest@2026!`
4. Check if discovery feed loads

**Expected:**
- If it works in incognito → browser extension is blocking WebSocket
- If it fails in incognito → not an extension issue

**If It Works in Incognito:**
- Extensions blocking the WebSocket include:
  - uBlock Origin (too aggressive)
  - Privacy Badger
  - Ghostery
  - Some VPNs
- Solution: Add `mixvy-v2.web.app` to allowlist in extension settings

---

### **Step 6: Cache Clear Test** (2 min)

**Steps:**
1. Open DevTools: **F12**
2. Right-click the reload button: **"Empty cache and hard reload"**
3. Wait for app to fully load
4. Check if issue persists

**Note:** Sometimes browser cache serves old version despite deployment

---

### **Step 7: Network Timeout Investigation** (5 min)

**Purpose:** Check if WebSocket is timing out before connection

**Steps:**
1. Open DevTools → **Console** tab
2. Paste this code:
   ```javascript
   // Monitor WebSocket attempts
   const originalFetch = window.fetch;
   window.fetch = function(...args) {
     if (args[0].includes('Listen')) {
       console.log('📡 WebSocket attempt:', args);
       console.time('WebSocket response');
     }
     return originalFetch.apply(this, args)
       .then(response => {
         if (args[0].includes('Listen')) {
           console.timeEnd('WebSocket response');
           console.log('📊 Response:', response.status, response.statusText);
         }
         return response;
       })
       .catch(err => {
         if (args[0].includes('Listen')) {
           console.error('❌ WebSocket error:', err);
         }
         throw err;
       });
   };
   console.log('✅ WebSocket monitor active');
   ```
3. Reload page
4. Watch console for timing info

**What to Look For:**
- How long does the request take?
- Does it ever get a response, or does it timeout?
- Time > 30s usually indicates timeout

---

## 📋 Debugging Report Template

When investigating, please gather:

```markdown
## Debugging Results

### Environment:
- Browser: [Chrome/Firefox/Safari/Edge]
- OS: Windows/Mac/Linux
- Incognito Mode: Yes/No
- Network: Direct/VPN/Proxy

### API Key Verification:
- Cloud Firestore API enabled: Yes/No
- mixvy-v2.web.app in whitelist: Yes/No

### Firebase Domains:
- mixvy-v2.web.app authorized: Yes/No
- mixvy-v2.firebaseapp.com authorized: Yes/No

### Network Tab Findings:
- Listen request status: [blank/101/other]
- Content-Type header: [paste]
- Access-Control-Allow-Origin: [paste]
- Full error text: [paste]

### Console Errors:
- Firestore errors: [list]
- CORS errors: [list]
- Other relevant errors: [list]

### Incognito Test:
- Works in incognito: Yes/No
- If Yes: Likely extension issue
- If No: System-level issue

### Response Time:
- WebSocket connection time: [X ms]
- Timeout detected: Yes/No
```

---

## 🎯 Most Likely Root Causes (in order of probability)

1. **🔴 HIGH PRIORITY:** API Key missing Firestore API permission
   - Fix time: 5 min
   - Symptom: All WebSocket requests abort immediately
   
2. **🟡 MEDIUM:** Browser extension blocking WebSocket
   - Fix time: 2 min
   - Symptom: Works in incognito, fails in normal mode
   
3. **🟡 MEDIUM:** Firestore console domain not authorized
   - Fix time: 5 min
   - Symptom: Domain mismatch error in console
   
4. **🟠 LOW:** Network timeout (slow connection)
   - Fix time: Varies
   - Symptom: Console shows very long response times

---

## Next Action
**Complete Steps 1-3 above and share findings. Include:**
1. API key settings screenshot
2. Firebase domain whitelist screenshot
3. Network tab error details (from Step 3)
4. Console errors (from Step 4)

These will pinpoint the exact cause!
