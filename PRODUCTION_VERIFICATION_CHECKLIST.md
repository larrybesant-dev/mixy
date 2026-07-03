# MixVy Production Verification Checklist (10 Minutes)

**Purpose:** Validate that production Stripe/Agora/GIPHY keys work before first real users  
**Date:** 2026-07-03  
**Tester:** [Your Name]  
**Result:** ☐ PASS / ☐ FAIL  

---

## Pre-Flight (1 minute)

- [ ] Firestore production database is accessible
- [ ] Firebase Console shows no permission errors
- [ ] Cloud Functions deployed (`validateMessageBlockEnforcement` + `validateConversationBlockEnforcement`)
- [ ] App running at production URL (not localhost)

---

## Test 1: Fresh Account Registration & Login (2 minutes)

**Objective**: Verify auth pipeline works end-to-end.

1. Open app in incognito/private browser tab
2. Tap **SIGN UP**
3. Enter:
   - Email: `test-user-1-[timestamp]@example.com` (e.g., `test-user-1-20260703@example.com`)
   - Password: `TestPass123!`
   - Confirm: `TestPass123!`
4. Tap **SIGN UP** button
5. Check email for verification link (may take 30 seconds)
6. Click verification link, return to app
7. Verify logged in: Home screen shows **MIX / CONNECT / INDULGE** nav

**Expected Result:**  
✅ Logged in successfully, home feed loads with rooms

**If Failed:**
- Check Firebase console for auth errors
- Verify reCAPTCHA configured for your domain
- Check browser console (F12) for errors

---

## Test 2: Stripe Integration - Coin Purchase (3 minutes)

**Objective**: Verify Stripe payment processing works with production keys.

1. From home screen, tap **Profile** (bottom right)
2. Tap **Wallet** or **Add Coins**
3. Select **70 Coins ($0.99)** package
4. Tap **Purchase**
5. **Use test Stripe card** (if Stripe in test mode):
   - Card: `4242 4242 4242 4242`
   - Expiry: `12/34`
   - CVC: `123`
6. Tap **Pay** or **Complete Purchase**
7. Wait for success screen

**Expected Result:**  
✅ Purchase completes, coins appear in wallet, transaction logged in Firestore

**Check Firestore** ([Console](https://console.firebase.google.com/project/mixvy-v2/firestore)):
- Navigate to **wallet_ledger** collection
- Find entry with:
  - `userId`: Your user ID
  - `type`: `purchase` or `coin_package`
  - `amount`: `70`
  - `balance_after`: `70` (first purchase)

**If Failed:**
- Check Stripe status page: https://status.stripe.com
- Verify Stripe keys in Cloud Functions environment
- Check [Firebase Functions Logs](https://console.firebase.google.com/project/mixvy-v2/functions/list)

---

## Test 3: Direct Gift Sending (2 minutes)

**Objective**: Verify gift transaction flow and coin deduction.

1. Open app in second browser (User 2) - can be different account or same
2. **User 1**: Navigate to discover feed
3. **User 1**: Tap any room or user card
4. **User 1**: Look for **Gift** button or icon
5. **User 1**: Select a gift (e.g., 🌹 Rose)
6. **User 1**: Confirm send (costs 10-50 coins based on gift)
7. Check balance updated: `Wallet: (70 - cost)` coins remaining

**Expected Result:**  
✅ Gift sent, coins deducted, balance updated in real-time

**Check Firestore** ([gift_events](https://console.firebase.google.com/project/mixvy-v2/firestore)):
- Find entry with:
  - `senderId`: Your user ID
  - `recipientId`: Recipient user ID
  - `giftId`: Gift ID
  - `coinCost`: Cost of gift
  - `timestamp`: Recent

**If Failed:**
- Check Agora/video keys (gift feature may depend on room state)
- Verify gift_events collection exists in Firestore
- Check Cloud Function logs for `sendDirectGift` errors

---

## Test 4: Message Sending & Block Enforcement (2 minutes)

**Objective**: Verify messaging works and block enforcement is active.

**Part A: Normal Message**
1. From profile, tap **Messages** tab
2. Start a new conversation with User 2
3. Type: "Hello! Testing MixVy production 🎉"
4. Send message
5. **In User 2's account**: See message appear

**Expected Result:**  
✅ Message appears instantly, no permission errors

**Part B: Block Enforcement**
1. **User 1**: Go to User 2's profile
2. Tap **Block User** (three dots menu)
3. **User 2**: Try to reply to User 1
4. Send message
5. **Check result**: Message should NOT appear in User 1's view

**Expected Result:**  
✅ Cloud Function deleted the blocked message automatically

**Check Logs** ([Firebase Functions](https://console.firebase.google.com/project/mixvy-v2/functions/list)):
- Click **validateMessageBlockEnforcement** function
- Check **Logs** tab
- Search for: `Message from blocked user deleted` or `Conversation from blocked user deleted`

**If Messages Not Sending:**
- Check Firestore permission rules
- Verify no other users blocking you
- Check message document structure matches schema

**If Block Enforcement Not Working:**
- Confirm Cloud Functions deployed (see functions list)
- Check function execution logs for errors
- Verify blocks collection exists and has entries

---

## Test 5: GIPHY Integration (1 minute)

**Objective**: Verify GIPHY API key is production (not sandbox).

1. In a message, look for **GIF** button or emoji picker
2. Search for a GIF (e.g., "celebration")
3. Select and send GIF
4. GIF should display in message thread

**Expected Result:**  
✅ GIF loads and displays correctly from GIPHY CDN

**If No GIFs Load:**
- GIPHY key may be sandbox/invalid
- Check `lib/config/app_env.dart` for `GIPHY_API_KEY`
- Go to [GIPHY Dashboard](https://developers.giphy.com/dashboard) and verify key is production
- Redeploy with correct key if needed

---

## Test 6: Agora Live Room (Optional, 1 minute)

**Objective**: Verify live video works with production Agora keys.

1. From home, tap **MIX** (first nav card)
2. Tap **Create Room** or tap existing room
3. Allow camera/microphone permissions
4. You should see your video preview
5. Invite User 2 to join
6. User 2 should see your stream

**Expected Result:**  
✅ Video streams without errors or latency issues

**If Video Fails:**
- Check Agora [Dashboard Status](https://console.agora.io)
- Verify Agora App ID in `lib/config/app_env.dart`
- Check browser console for WebRTC errors (F12)

---

## Summary

| Test | Result | Notes |
|------|--------|-------|
| Registration & Login | ☐ ✅ ☐ ❌ | |
| Stripe - Coin Purchase | ☐ ✅ ☐ ❌ | |
| Direct Gift Send | ☐ ✅ ☐ ❌ | |
| Messaging & Block | ☐ ✅ ☐ ❌ | |
| GIPHY Integration | ☐ ✅ ☐ ❌ | |
| Agora Live Room | ☐ ✅ ☐ ❌ | Optional |

**Overall Result:** 
- **All Pass (5+/6)**: ✅ **READY FOR SOFT LAUNCH** → Invite first 50 users
- **1-2 Failures**: ⚠️ **CONDITIONAL** → Fix issues, re-run failed tests
- **3+ Failures**: ❌ **NOT READY** → Hold for further investigation

---

## Critical Issues Found?

If you encounter critical issues:

1. **Screenshot the error** (F12 DevTools)
2. **Check [Firebase Console](https://console.firebase.google.com/project/mixvy-v2)**:
   - Functions → Logs (check for function execution errors)
   - Firestore → Data (verify collections/documents exist)
   - Authentication → Users (verify account created)
3. **Check Stripe/Agora Status Pages** for outages
4. **Review `PRODUCTION_KEY_AUDIT.md`** (see next file)

---

## When to Proceed to Soft Launch

✅ Proceed when:
- All 5 core tests pass
- No errors in Firebase Functions logs
- Coins were actually deducted from wallet
- Messages appear in conversation thread
- Blocks prevent message delivery

❌ Do NOT proceed until:
- Block enforcement is confirmed working
- Stripe successfully charged account
- No permission denials in Firestore logs
- Agora video (if enabled) works without lag

---

**Checklist Version:** 1.0  
**Last Updated:** 2026-07-03  
**Next Review:** After first 50 users (soft launch)
