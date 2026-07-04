# Production Verification System Checklist

## System Architecture

**Three-Tier Verification Model:**
1. **User Created** → Automatic `verification/{uid}` document created by Cloud Function with `verificationStatus: "pending"`, `isAdultVerified: false`
2. **Admin Review** → Manual Firestore console update to set `verificationStatus: "verified"` and `isAdultVerified: true`
3. **Access Granted** → Firestore rules enforce `isAdultVerified()` function check; user can now join rooms

---

## End-to-End Test Flow

### Step 1: New User Signup (Automated)
```
Expected: Cloud Function onUserCreated triggers automatically on user document creation
Verify: Within 5-10 seconds, a verification/{uid} document appears in Firestore with:
  - userId: (user's UID)
  - isAdultVerified: false
  - verificationStatus: "pending"
  - createdAt: (server timestamp)
  - updatedAt: (server timestamp)
```

**Test Procedure:**
1. Sign up a new test account in MIXVY app
2. Go to Firebase Console → Firestore → `verification` collection
3. Look for the new document matching the signed-up user's UID
4. Verify all fields are present and correct

**Expected Result:** ✅ Document created automatically by Cloud Function
---

### Step 2: User Attempts Room Join (Permission Denied)
```
Expected: User can authenticate but CANNOT join rooms
Error: [cloud_firestore/permission-denied] Missing or insufficient permissions
Reason: Firestore rules enforce isAdultVerified() → requires isAdultVerified: true
```

**Test Procedure:**
1. Login as the newly created test user
2. Navigate to any available room
3. Click "Join Room" / "Enter Room" button
4. Observe error notification

**Expected Result:** ❌ Permission denied error (this is correct behavior)

---

### Step 3: Admin Verification (Manual)
```
Required: Manual Firebase console action to enable user access
Action: Update verification/{uid} document to set isAdultVerified and verificationStatus
```

**Test Procedure:**
1. Go to Firebase Console
2. Navigate to Firestore → `verification` collection
3. Find the test user's verification document
4. Click "Edit" on the document
5. Update two fields:
   - `isAdultVerified`: change from `false` to `true`
   - `verificationStatus`: change from `"pending"` to `"verified"`
6. Click Save

**Console Screenshot Markers:**
- Document path: `verification/{testUserUID}`
- Updated timestamp: Should show current time
- Fields edited: `isAdultVerified = true`, `verificationStatus = "verified"`

---

### Step 4: User Joins Room (Success)
```
Expected: After admin verification, user can successfully join rooms
Firebase Rule Chain:
  1. roomReadableByRequester() checks isAdultVerified()
  2. isAdultVerified() checks: exists(verification/{uid}) AND 
                                verificationStatus == "verified" AND
                                isAdultVerified == true
  3. If true → participant can be created → room join succeeds
```

**Test Procedure:**
1. Clear app cache or logout/login
2. Login as the verified test user
3. Navigate to same room
4. Click "Join Room" button
5. Observe successful room entry

**Expected Result:** ✅ User successfully joins room

---

## Verification Document Schema

### Location
```
Collection: verification
Document ID: {user's UID}
```

### Required Fields
```json
{
  "userId": "string (user's UID)",
  "isAdultVerified": "boolean (true = verified, false = pending)",
  "verificationStatus": "string (enum: 'pending', 'verified', 'suspended')",
  "createdAt": "timestamp (server timestamp, auto-generated)",
  "updatedAt": "timestamp (server timestamp, auto-updated)"
}
```

### Example Document
```json
{
  "userId": "abc123xyz789",
  "isAdultVerified": true,
  "verificationStatus": "verified",
  "createdAt": "2026-07-03T18:46:00Z",
  "updatedAt": "2026-07-03T19:15:30Z"
}
```

---

## Firestore Rules Reference

### Key Function: `isAdultVerified(userId)`
**Location:** `firestore.rules` lines 51-61

```
function isAdultVerified(userId) {
  return exists(/databases/$(database)/documents/verification/$(userId)) &&
         get(/databases/$(database)/documents/verification/$(userId)).data.verificationStatus == "verified" &&
         get(/databases/$(database)/documents/verification/$(userId)).data.isAdultVerified == true;
}
```

**What it does:**
- Requires verification document to exist
- Requires `verificationStatus` field to be exactly `"verified"`
- Requires `isAdultVerified` field to be exactly `true`
- Returns `true` only if ALL three conditions are met

### Permission Chain for Room Join
```
participant create rule
  → canReadRoomById(roomId)
    → roomReadableByRequester(roomData)
      → isAdultVerified(userId)  ← GATEKEEPER
```

If any step fails, entire chain fails → permission-denied error

---

## Cloud Function: onUserCreated

**Location:** `functions/index.js` lines 3035-3062

**Trigger:** `onDocumentCreated("users/{uid}")`

**Behavior:**
1. Fires automatically when new user document is created in `/users/{uid}`
2. Creates corresponding document in `/verification/{uid}` with:
   - `userId`: user's UID
   - `isAdultVerified`: `false` (default pending state)
   - `verificationStatus`: `"pending"` (requires admin approval)
   - `createdAt`: server timestamp
   - `updatedAt`: server timestamp

**Error Handling:**
- Catches and logs errors to Cloud Functions console
- Does not block user creation; only verification document creation
- If function fails, user still exists but cannot join rooms

---

## Troubleshooting Guide

### Issue: User Created But Cannot Join Room
**Check:**
1. Does `verification/{uid}` document exist in Firestore?
   - If NO: Cloud Function failed to trigger or execute → Check Cloud Functions logs
   - If YES: Is `isAdultVerified: true` AND `verificationStatus: "verified"`?
     - If NO: Admin hasn't approved yet (correct)
     - If YES: Check Firestore rules compile without errors

**Solution:**
- Wait 10 seconds for Cloud Function to trigger
- Check Firebase Console → Cloud Functions → `onUserCreated` → Logs tab
- Look for errors in execution logs
- If document never appeared, check that users are being created properly

### Issue: Firestore Rules Syntax Error
**Symptoms:** All room operations fail immediately for all users

**Fix:**
1. Go to Firebase Console → Firestore → Rules tab
2. Click "Validate rules"
3. Look for red compilation errors
4. Verify `isAdultVerified()` function is defined before use
5. Check line 51-61 for proper function syntax

### Issue: Permission Denied on Room Operations
**Check Sequence:**
1. Is user authenticated? (Check Auth console)
2. Does `verification/{uid}` document exist?
3. Is `isAdultVerified: true` AND `verificationStatus: "verified"`?
4. Do Firestore rules compile without errors?
5. Is room document's `isAdult` field set to `false` or `true`?

**Solutions:**
- If verification doc missing: Manually create it in Firestore console
- If fields wrong: Manually update to `isAdultVerified: true`, `verificationStatus: "verified"`
- If rules don't compile: Review function syntax and ensure no typos

---

## Admin Approval Workflow (Current Manual Process)

### For Each New User Request
1. **Monitor** Firestore `verification` collection for `verificationStatus: "pending"` docs
2. **Review** user's profile/account for compliance (manual step - not automated)
3. **Update** verification document:
   ```
   isAdultVerified: true
   verificationStatus: "verified"
   ```
4. **Notify** user that they're verified (out-of-app process)
5. **Monitor** for user's first room join attempt

### Bulk Verification (If Needed)
- Go to Firebase Console → Firestore → `verification` collection
- Filter for `verificationStatus == "pending"`
- Batch edit to set `isAdultVerified: true`, `verificationStatus: "verified"`

---

## Production Safeguards

**Firestore Rules** (Strict by default):
- ✅ Unauthenticated users: Cannot access any collections
- ✅ Authenticated users: Can only access if `isAdultVerified()`
- ✅ No self-service verification: Users cannot write to own `verification` doc
- ✅ Admin-controlled: Only Firestore console can modify verification status

**Cloud Function** (Auto-remediation):
- ✅ All new users get automatic verification document
- ✅ Default state: `isAdultVerified: false` (safe default)
- ✅ Requires explicit admin action to enable access

**Zero-Trust Architecture**:
- ✅ No client-side verification flags
- ✅ All checks server-side via Firestore rules
- ✅ No way to bypass verification once rules are deployed

---

## Testing Checklist

- [ ] New user signs up → `verification/{uid}` document auto-created within 10 seconds
- [ ] Unverified user attempts room join → Permission denied error
- [ ] Admin updates `isAdultVerified: true` and `verificationStatus: "verified"`
- [ ] Verified user attempts room join → Success
- [ ] Unverified user cannot create rooms
- [ ] Unverified user cannot send messages in existing rooms
- [ ] Unverified user cannot create participants documents
- [ ] Verified user can perform all above actions
- [ ] Multiple concurrent user signups create correct documents
- [ ] Firebase rules compile without syntax errors
- [ ] Cloud Function `onUserCreated` appears in Cloud Functions console
- [ ] No errors in Cloud Function execution logs

---

## Deployment History

| Date | Component | Change | Status |
|------|-----------|--------|--------|
| 2026-07-03 | Firestore Rules | Deployed `isAdultVerified()` strict enforcement | ✅ Deployed |
| 2026-07-03 | Cloud Functions | Deployed `onUserCreated` trigger | ✅ Deployed |
| 2026-07-03 | firebase.json | Restored pre-deploy validation script | ✅ Restored |

---

## Next Steps

**Soft-Launch → Production Transition:**
1. ✅ Deploy strict Firestore rules with `isAdultVerified()` checks
2. ✅ Deploy Cloud Function `onUserCreated` to auto-create verification docs
3. ✅ Remove soft-launch bypass (`|| signedIn()` fallback)
4. ⏳ Execute this end-to-end test with at least 3 new users
5. ⏳ Document any issues or edge cases discovered
6. ⏳ Establish admin approval SLA (e.g., "Verify within 24 hours")
7. ⏳ Create admin dashboard or script for bulk verification (optional future feature)

---

**Last Updated:** 2026-07-03  
**Verified By:** Production Verification System  
**Status:** ✅ System Live and Ready for Testing
