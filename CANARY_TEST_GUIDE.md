# MIXVY Canary Load Testing Guide

**Date:** 2026-06-29  
**Version:** 1.0  
**Purpose:** Professional synthetic load testing framework for MIXVY app

---

## 🎯 Quick Start

### Option 1: Full Automated Canary Test (Recommended for First Run)

```bash
# Run the complete orchestrated test
node run-canary-test.js

# When finished, cleanup bot accounts
node run-canary-test.js --cleanup
```

**What This Does:**
1. ✅ Validates prerequisites (Node.js, Firebase CLI, Playwright)
2. ✅ Creates 5 test bot accounts in production Firebase
3. ✅ Launches browser automation for each bot
4. ✅ Monitors WebRTC latency and performance
5. ✅ Generates comprehensive report
6. ✅ (Optional) Cleans up all test accounts

**Time Required:** ~15 minutes  
**Firebase Cost:** ~$0.10-$0.50 USD

---

### Option 2: Manual Step-by-Step Testing

If you want more control, run each phase independently:

```bash
# Phase 1: Create 5 canary bot accounts
node load-test-canary.js

# Phase 2: Run browser automation for Bot 1
node load-test-browser-bots.js --email canarybot1@canarybot-mixvy-test.com --password CanaryBot1@Secure2026

# Phase 3: (repeat for bots 2-5 with different emails/passwords)

# Phase 4: Cleanup when done
node load-test-canary.js --cleanup
```

---

## 🔒 Safety & Isolation

### Production Data Protection

✅ **Bot Account Tagging**
- All test users marked with `_isCanaryBot: true` in Firestore
- Email domain: `canarybot-mixvy-test.com` (obviously test accounts)
- Prefix: `canarybot1`, `canarybot2`, etc.

✅ **Easy Identification & Cleanup**
```javascript
// Query to find all canary bots
db.collection('users').where('_isCanaryBot', '==', true)

// Cleanup script automatically removes all test data
node load-test-canary.js --cleanup
```

✅ **Non-Destructive**
- No production user data is modified
- No live room data is corrupted
- All test data isolated in test accounts

### Firebase Quota Protection

⚠️ **WARNING: Firebase Rate Limits**

Firebase has default rate limits:
- **Auth:** 300 account creations per minute per IP
- **Firestore:** 10,000 writes per minute per database

**Our Canary Approach:**
- Only 5 bots (well under limits)
- Sequential execution (not parallel)
- 5-second delays between bots
- Graceful handling of rate limit errors

⚠️ **To Scale to 100 Bots:**
1. Contact Firebase Support to increase quotas
2. Use separate Firebase project for load testing
3. Implement progressive ramp-up (10 → 50 → 100)
4. Monitor quota usage in real-time

---

## 📊 What Gets Tested

### Account Lifecycle
```
1. Bot Account Creation
   - Firebase Auth user created
   - Firestore user profile created
   - Avatar URL generated

2. Bot Login
   - Email/password authentication
   - Session established
   - User profile loaded
```

### Room Interactions
```
3. Room Discovery
   - Query live rooms from Firestore
   - Load discovery feed
   - Display avatars (✅ NEW FEATURE)

4. Room Join
   - Find random live room
   - Create participant document
   - Update room member count
   - Store avatar URL (✅ AVATAR DENORMALIZATION)

5. Chat Messaging
   - Send message to room
   - Verify message appears in real-time
   - Check chat latency
```

### Social Features
```
6. User Follow
   - Select random user
   - Create follow relationship
   - Update follower count
```

### Performance Metrics Monitored
- ⏱️ Page load time
- 🎙️ WebRTC connection latency
- 💾 Firestore operation latency
- 📊 Number of concurrent operations
- 💥 Error rates and error types

---

## 📈 Interpreting Results

### Browser DevTools - Console Tab

Look for these key log patterns:

```javascript
// Good signs ✅
[Firebase] Firestore initialized successfully
[ROUTER] Route navigation complete
[WebRTC] Connection established - latency: 45ms
[Chat] Message sent and confirmed

// Warning signs ⚠️
Missing or insufficient permissions
[cloud_firestore/deadline-exceeded]
[WebRTC] Connection timeout
Maximum call stack size exceeded

// Bad signs ❌
[cloud_firestore/permission-denied]
[cloud_firestore/unavailable]
ReferenceError: Cannot read property 'uid' of undefined
WebRTC connection failed
```

### Browser DevTools - Network Tab

Check for:
1. **JS Bundle Size** - Should be < 5MB (gzipped)
2. **Image Load Times** - Avatars should load in < 500ms
3. **Firestore Requests** - Should complete in < 1000ms
4. **Failed Requests** - Should be 0

### Firebase Console - Firestore Stats

Navigate to: **Firebase Console > Firestore > Stats**

```
Read Operations:  ~200-300 (5 bots joining rooms)
Write Operations: ~150-200 (participant + message + follow)
Stored Data:      +5 user profiles + test data
```

---

## 🔍 Common Issues & Solutions

### Issue 1: "Permission Denied" Error

**Error:** `Missing or insufficient permissions [cloud_firestore/permission-denied]`

**Root Cause:** Firestore security rules don't allow the operation

**Solution:**
1. Check firestore.rules was updated correctly
2. Verify avatar URL fields are in allowed list
3. Redeploy rules: `firebase deploy --only firestore:rules`

**Code Reference:** [firestore.rules](firestore.rules#L453-L485)

---

### Issue 2: Avatar URLs Not Appearing

**Symptom:** Room cards show gray circles instead of user images

**Root Cause:** `_clusterAvatarUrls()` returns empty array

**Solution:**
1. Check RoomModel has `stageUserAvatarUrls` and `audienceUserAvatarUrls` fields
2. Verify join logic stores avatar URL: `FieldValue.arrayUnion([avatarUrl ?? ''])`
3. Check CachedNetworkImage is receiving non-empty URLs

**Code Reference:**
- [lib/models/room_model.dart](lib/models/room_model.dart#L22-L23)
- [lib/features/room/presentation/live_room_screen.dart](lib/features/room/presentation/live_room_screen.js#L96)
- [lib/features/feed/screens/discovery_feed_screen.dart](lib/features/feed/screens/discovery_feed_screen.dart#L2235)

---

### Issue 3: Bot Can't Login

**Error:** `Login failed` / Blank login form

**Root Cause:** Flutter canvas UI not rendering in headless browser

**Solution:**
1. Run with `--headless=false` to see browser window
2. Check browser console for JS errors
3. Verify Firebase project allows email/password auth
4. Check network requests in DevTools > Network tab

---

### Issue 4: WebRTC Connection Timeout

**Error:** `WebRTC connection timeout after 30s`

**Root Cause:** WebRTC signaling or media connection issues

**Solution:**
1. Check peer connection logs in browser console
2. Verify STUN/TURN servers are reachable
3. Check browser permissions (camera/microphone)
4. Review WebRTC implementation in codebase

---

## 📋 Monitoring Checklist

### Before Running Test
- [ ] Firebase project is accessible
- [ ] Firestore rules have been deployed
- [ ] No active DDoS or attack alerts in Firebase
- [ ] Disk space available for browser cache
- [ ] Stable internet connection

### During Test
- [ ] Keep browser DevTools open (Console + Network tabs)
- [ ] Monitor CPU/Memory in Task Manager
- [ ] Watch for Firebase error messages
- [ ] Note any WebRTC connection issues

### After Test
- [ ] Review CANARY_TEST_REPORT.md
- [ ] Check Firefox/Chrome cache size
- [ ] Review Firestore billing impact
- [ ] Document any issues found
- [ ] Clean up test bot accounts

---

## 🚀 Scaling Beyond Canary

### When Ready to Scale to 20 Bots

```bash
# Modify load-test-canary.js
const CANARY_BOT_COUNT = 20;

# Run test
node run-canary-test.js --cleanup
```

### When Ready to Scale to 100 Bots

**Prerequisites:**
1. ✅ Canary test (5 bots) passed
2. ✅ All identified issues fixed
3. ✅ Firebase quota increased (contact support)
4. ✅ Performance monitoring in place

**Implementation:**
```bash
# Use separate Firebase project
export FIREBASE_PROJECT_ID=mixvy-load-test

# Implement parallel bot execution
# (modify run-canary-test.js to spawn multiple bots in parallel)

# Run with gradual ramp-up
node run-canary-test.js --max-bots=100 --ramp-up=linear
```

---

## 📝 Scripts Reference

### load-test-canary.js
**Purpose:** Create/delete test user accounts  
**Actions:** Firebase Auth + Firestore user profile  
**Time:** ~2 minutes to create 5 accounts  

```bash
# Create bots
node load-test-canary.js

# Delete bots
node load-test-canary.js --cleanup
```

### load-test-browser-bots.js
**Purpose:** Automate browser interactions for single bot  
**Actions:** Login → Join room → Send message → Check metrics  
**Time:** ~2-3 minutes per bot  

```bash
# Run for specific bot
node load-test-browser-bots.js \
  --email canarybot1@canarybot-mixvy-test.com \
  --password CanaryBot1@Secure2026
```

### run-canary-test.js
**Purpose:** Orchestrate full end-to-end test  
**Actions:** Create bots → Automation → Report → Cleanup  
**Time:** ~15 minutes total  

```bash
# Full test with cleanup
node run-canary-test.js --cleanup

# Full test without cleanup (for inspection)
node run-canary-test.js
```

---

## 💡 Pro Tips

1. **Keep Browser Window Open** - The `load-test-browser-bots.js` script launches visible browser windows so you can watch the automation happen and see any UI issues in real-time.

2. **Monitor DevTools Console** - Look for `[WebRtcLatency]` logs during room calls to benchmark actual latency.

3. **Test During Low-Traffic Hours** - Run canary tests when app traffic is low to isolate performance issues.

4. **Use Firebase Emulator for Development** - For iterative testing, use Firebase Emulator to avoid costs and rate limits.

5. **Capture Screenshots** - Consider adding screenshot capture in browser automation script to document issues.

6. **Use --headless=false** - Set `headless: false` in Chromium launch to debug UI rendering issues.

---

## 🆘 Getting Help

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `ENOENT: no such file` | Script not found | Check working directory is `/MIXVY` |
| `firebase not found` | Firebase CLI not installed | `npm install -g firebase-tools` |
| `Permission denied` | Firestore rules blocking | Re-deploy firestore.rules |
| `Module not found` | Missing npm package | `npm install` in project root |
| `WebRTC timeout` | Connection issue | Check browser console logs |

### Debug Mode

Enable verbose logging:

```bash
# Add debug logging
export DEBUG=*
node run-canary-test.js

# Check Firebase emulator logs
firebase emulators:start --inspect-functions
```

---

## 📚 Related Documentation

- [Avatar Denormalization Implementation](TESTING_REPORT.md)
- [Firestore Security Rules](firestore.rules)
- [RoomModel with Avatar Fields](lib/models/room_model.dart)
- [Join/Leave Logic with Avatars](lib/features/room/presentation/live_room_screen.dart)

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-06-29 | 1.0 | Initial canary test suite |

---

*Last Updated: 2026-06-29*  
*Test Framework Status: Ready for Production Canary Testing*
