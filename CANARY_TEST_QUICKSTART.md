# 🚀 MIXVY Professional Load Testing - Quick Start

## Status: ✅ READY FOR CANARY TESTING

Everything is set up and ready to run. Follow these simple steps:

---

## 📊 Quick Start: Run Canary Test (15 minutes)

```bash
# Navigate to project directory
cd C:\Users\LARRY\MIXVY

# Run the complete automated test suite
node run-canary-test.js

# When finished, cleanup test accounts (optional)
node run-canary-test.js --cleanup
```

**That's it!** The script will:
1. ✅ Create 5 test bot accounts
2. ✅ Launch browser automation for each bot
3. ✅ Monitor performance metrics
4. ✅ Generate comprehensive report
5. ✅ Optionally cleanup all test data

---

## 📁 Files Created

| File | Purpose | Size |
|------|---------|------|
| `run-canary-test.js` | 🎯 **Main entry point** - Orchestrates full test | 8.5 KB |
| `load-test-canary.js` | 👤 Creates/deletes test bot accounts | 12 KB |
| `load-test-browser-bots.js` | 🌐 Playwright browser automation | 10 KB |
| `CANARY_TEST_GUIDE.md` | 📖 Complete documentation | 15 KB |
| `CANARY_TEST_REPORT.md` | 📈 Generated after each test run | Variable |

---

## 🎯 What Gets Tested

```
✅ Account Creation
   └─ Firebase Auth user creation
   └─ Firestore profile with avatar URL
   └─ Test account tagging for easy cleanup

✅ Login & Authentication
   └─ Email/password authentication
   └─ Session management
   └─ User data loading

✅ Room Discovery
   └─ Firestore room queries
   └─ Avatar display (NEW FEATURE! 🎉)
   └─ Member count accuracy

✅ Room Join/Leave
   └─ Participant document creation
   └─ Avatar URL denormalization (NEW! 🎉)
   └─ Real-time member updates

✅ Chat Messaging
   └─ Message submission
   └─ Real-time delivery
   └─ Message latency monitoring

✅ Social Features
   └─ User follow relationships
   └─ Follower count updates

✅ Performance Metrics
   └─ Page load time
   └─ WebRTC connection latency
   └─ Firestore operation latency
   └─ Error rates
```

---

## 🔒 Safety Features

### ✅ Production Data Protection
- All test users tagged with `_isCanaryBot: true`
- Email domain: `canarybot-mixvy-test.com` (obviously test accounts)
- Completely isolated from real user data

### ✅ Easy Cleanup
```bash
# Delete all canary bot accounts with one command
node load-test-canary.js --cleanup
```

### ✅ Firebase Quota Safe
- Only 5 bots (well under Firebase rate limits)
- Sequential execution (not parallel)
- Automatic rate limit error handling

### ✅ Cost Efficient
- Estimated Firebase cost: **$0.10-$0.50 USD**
- Runs on production database (optional: use emulator)
- No permanent data left behind after cleanup

---

## 📈 What You'll See

### During Test
```
Phase 1: Creating 5 Canary Bot Accounts...
  ✅ Created canarybot1@canarybot-mixvy-test.com
  ✅ Created canarybot2@canarybot-mixvy-test.com
  ...

Phase 2: Running Browser Automation...
  🌐 Starting browser automation for Bot 1...
  🔐 Logging in...
  🎙️  Joining room...
  💬 Sending chat message...
  ✅ Bot 1 automation completed

Phase 3: Performance Analysis...
  📊 Analyzing metrics...
  ⏱️  Page load time: 2.3s
  🎙️  WebRTC latency: 87ms
  💾 Firestore ops: 45ms

Phase 4: Generating Report...
  📝 Report saved to: CANARY_TEST_REPORT.md
```

### After Test
- Browser windows close automatically
- Full report generated: `CANARY_TEST_REPORT.md`
- Test data available for inspection or cleanup

---

## 🎨 Avatar Feature Validation

The canary test **specifically validates the new avatar feature**:

```
✅ Avatar URLs stored with user IDs
   └─ stageUserAvatarUrls parallel array
   └─ audienceUserAvatarUrls parallel array

✅ Avatars displayed on discovery feed
   └─ RoomAvatarStack shows 4 overlapping images
   └─ Real user profile pictures instead of gray circles

✅ Real-time avatar updates
   └─ Avatar appears when user joins
   └─ Avatar disappears when user leaves

✅ Firestore sync integrity
   └─ ID and URL arrays stay synchronized
   └─ No orphaned or mismatched entries
```

---

## 🔍 Monitoring During Test

### Browser DevTools (Press F12)

**Console Tab:**
- Look for `[WebRtcLatency]` logs
- Check for errors starting with `[Error]` or `[cloud_firestore/`
- Monitor performance warnings

**Network Tab:**
- Verify Firestore requests complete in < 1000ms
- Check image loads (avatars) complete in < 500ms
- Monitor for failed requests (should be 0)

**Performance Tab:**
- Track FCP (First Contentful Paint)
- Monitor LCP (Largest Contentful Paint)
- Profile CPU/Memory usage

### Firebase Console

Go to: **Firebase Console > mixvy-v2 > Firestore > Stats**

Monitor:
- Read/Write operations spike during test
- Latency metrics for database operations
- Check for any rate limit errors (429)

---

## 📊 Expected Results

### ✅ Successful Test
- All 5 bots created without errors
- All bots log in and join rooms
- Chat messages sent and received
- Avatar URLs display correctly
- WebRTC latency: 50-200ms ✅
- Firestore latency: 50-150ms ✅
- No permission errors ✅

### ⚠️ Issues to Watch For
- "Permission denied" errors → Firestore rules issue
- Avatar URLs not appearing → Join/Leave logic issue
- WebRTC timeout → Network/connection issue
- Firestore rate limiting (429) → Quota exceeded

---

## 🚀 Scaling After Canary

### If Canary Test Passes ✅
1. Run canary again to confirm consistency
2. Review Firebase usage and costs
3. Fix any minor issues identified
4. Scale to 20 bots: modify `CANARY_BOT_COUNT = 20`
5. Eventually scale to 100 bots

### If Issues Found ⚠️
1. Note error type and frequency
2. Review `CANARY_TEST_REPORT.md` for details
3. Check browser DevTools console
4. Fix identified issue in codebase
5. Re-run canary test to validate fix
6. Only scale when all issues resolved

---

## 📖 Documentation

### Quick Reference
- **CANARY_TEST_GUIDE.md** - Full testing guide with troubleshooting
- **TESTING_REPORT.md** - Comprehensive testing checklist
- **This file** - Quick start reference

### Code Reference
- [Avatar denormalization in RoomModel](lib/models/room_model.dart#L22-L23)
- [Join logic with avatar storage](lib/features/room/presentation/live_room_screen.dart#L60-L96)
- [Leave logic with avatar cleanup](lib/features/room/presentation/live_room_screen.dart#L135-L175)
- [Avatar retrieval in feed](lib/features/feed/screens/discovery_feed_screen.dart#L2235-L2260)

---

## 🆘 Troubleshooting

### Error: "Permission denied"
→ Run: `firebase deploy --only firestore:rules`

### Error: "Firebase not found"
→ Run: `npm install -g firebase-tools`

### Error: "Module not found"
→ Run: `npm install` in project root

### Avatars not displaying
→ Check firestore.rules includes `audienceUserAvatarUrls`

### WebRTC timeout
→ Check browser console for connection errors

**For more help:** See CANARY_TEST_GUIDE.md section "🔍 Common Issues & Solutions"

---

## ⏱️ Timeline

```
00:00 - Test starts
00:02 - 5 bots created
00:03-12:00 - Browser automation runs (2-3 min per bot)
12:00-13:00 - Performance analysis
13:00-14:00 - Report generation & final checks
14:00-15:00 - Optional cleanup
15:00 - Complete! ✅
```

**Total Duration:** ~15 minutes

---

## 💰 Cost Estimate

```
Test Component          Operations    Estimated Cost
─────────────────────────────────────────────────────
User account creation   5 auth users  $0.01
Firestore reads         ~250 reads    $0.10
Firestore writes        ~200 writes   $0.10
Storage (avatars)       ~5 images     Minimal
─────────────────────────────────────────────────────
TOTAL                                 $0.20-$0.50 USD
```

*Much cheaper than 100 bots! And safer to validate first.*

---

## 🎉 Next Steps

**Now:**
1. ✅ Review all scripts created
2. ✅ Read CANARY_TEST_GUIDE.md for full details
3. ✅ Run: `node run-canary-test.js`

**After Canary Passes:**
1. ✅ Review CANARY_TEST_REPORT.md
2. ✅ Fix any issues found
3. ✅ Scale to 20 bots
4. ✅ Eventually scale to 100 bots

**Production Release:**
1. ✅ Monitor avatar feature in live app
2. ✅ Track WebRTC latency metrics
3. ✅ Watch Firestore performance
4. ✅ Celebrate launch! 🚀

---

## 📞 Support

- **Questions?** Check CANARY_TEST_GUIDE.md
- **Script Issues?** Review error output in console
- **Firebase Issues?** Check Firebase Console > Firestore > Stats
- **WebRTC Issues?** Check browser DevTools > Console for [WebRtcLatency] logs

---

**Status:** ✅ READY FOR TESTING  
**Last Updated:** 2026-06-29  
**Framework Version:** 1.0  
**Avatar Feature:** ✅ IMPLEMENTED & READY FOR LOAD TESTING

**Ready to launch? Run:** `node run-canary-test.js` 🚀
