# MIXVY Firestore Connection Issue - Troubleshooting Guide

## 🔴 CRITICAL ISSUE
Real-time Firestore connections are being aborted with `net::ERR_ABORTED` errors approximately every 60-120 seconds.

---

## ✅ WHAT WE'VE VERIFIED

- ✅ Firebase project: `mix-and-mingle-v2` (project ID: 980846719834)
- ✅ Firebase Web Config deployed correctly
- ✅ Firestore Rules file exists and is valid
- ✅ Firebase Hosting domain: `mixvy-v2.web.app`
- ✅ Flutter/Dart code properly initializes Firebase
- ✅ Auth tokens are valid (users can authenticate)
- ✅ Firestore reads work (discovery feed loads)
- ✅ Only real-time listeners (snapshots()) fail

---

## 🔍 ROOT CAUSE - Firebase Backend Configuration

The issue is NOT in the app code. It's a Firebase backend problem where:

1. **Firestore is rejecting long-polling connections after ~60 seconds**
   - Symptom: Multiple "net::ERR_ABORTED" errors on Firestore/Listen/Write channels
   - Pattern: Repeating every 60-120 seconds with new session IDs

2. **Possible causes:**
   - Domain not whitelisted in Firebase Console
   - Firestore quotas/rate limiting
   - CORS headers not configured for web domain
   - Firestore service backend issue

---

## 🛠️ FIXES NEEDED IN FIREBASE CONSOLE

### **Step 1: Verify Firebase Project Settings**

1. Go to [Firebase Console](https://console.firebase.google.com/project/mixvy-v2/settings/general)
2. Ensure under "Authorized Domains":
   - ✅ `mixvy-v2.firebaseapp.com` (authentication domain)
   - ✅ `mixvy-v2.web.app` (hosting domain)
   - Add if missing

### **Step 2: Check Firestore Database Settings**

1. Go to [Firestore Settings](https://console.firebase.google.com/project/mixvy-v2/firestore/settings)
2. Under "Database Settings":
   - Verify location is set (should be `us-central1` or your region)
   - Check if there are any quotas being exceeded

### **Step 3: Enable Network Diagnostics**

1. In [Firebase Console](https://console.firebase.google.com/project/mixvy-v2/monitoring/realtime)
2. Check for:
   - Firestore connection errors
   - Rate limiting
   - Quota exceeded warnings

### **Step 4: Review Security Rules**

In [Firestore Security Rules](https://console.firebase.google.com/project/mixvy-v2/firestore/rules):

Current rules allow authenticated access. Verify they're published:
```
✅ Should show: "Last published 2024-..."
❌ If shows "Not published" - publish them immediately
```

---

## 🔧 TEMPORARY WORKAROUNDS (Client-Side)

We've implemented in code:

1. **Enhanced Error Logging**
   - Monitor console for specific error patterns
   - Track Firestore connection health

2. **Connection Health Monitor** (`firestore_health_monitor.dart`)
   - Detects degraded/offline status
   - Can trigger fallback UI

3. **Improved Settings** (`firebase_providers.dart`)
   - Disabled persistence to avoid corruption
   - Configured cache size for better resilience

---

## ❌ WHAT DOESN'T WORK (Due to Backend Issue)

- ❌ Real-time room participant sync
- ❌ Live message delivery
- ❌ Audio/video state propagation
- ❌ Participant list updates
- ❌ Any `.snapshots()` based features

---

## ✅ WHAT STILL WORKS

- ✅ User authentication
- ✅ One-time data fetches
- ✅ Page loads with static data
- ✅ File uploads to Storage
- ✅ Cloud Functions calls
- ✅ Basic navigation

---

## 📞 RECOMMENDED NEXT STEPS

1. **Check Firebase Status**: https://status.firebase.google.com/
2. **Contact Firebase Support** with:
   - Project ID: `mix-and-mingle-v2`
   - Domain: `mixvy-v2.web.app`
   - Error: `net::ERR_ABORTED` on Firestore Listen channels
   - Frequency: Every 60-120 seconds

3. **Try these diagnostic steps:**
   - [ ] Clear browser cache/cookies
   - [ ] Try from incognito window
   - [ ] Try from different network
   - [ ] Check [Firebase Status Page](https://status.firebase.google.com/)

4. **Escalate to Google Cloud Support** if issue persists

---

## 📊 Evidence

Console errors show:
```
[2026-06-27T14:50:45.162Z] GET Firestore/Listen/channel... failed: "net::ERR_ABORTED"
[2026-06-27T14:51:31.249Z] GET Firestore/Listen/channel... failed: "net::ERR_ABORTED"
[2026-06-27T14:51:45.306Z] GET Firestore/Write/channel... failed: "net::ERR_ABORTED"
...patterns repeat every 60-120 seconds...
```

This pattern is consistent with **server-side connection termination**, not client-side issues.

---

## 💾 Code Changes Made

All client-side mitigations implemented in June 27, 2026 deployment:
- Firebase initialization enhanced logging
- Firestore connection health monitoring added  
- Error handling improved throughout
- Resilience extensions added to queries/docs

But these are **diagnostic/resilience improvements**, not fixes for the backend issue.
