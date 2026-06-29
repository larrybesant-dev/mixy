# Firestore Security Rules - Quick Reference

**Last Updated:** June 26, 2026

---

## Rule Deployment

```bash
# Test rules locally
firebase emulators:start --only firestore

# Deploy to production (from project root)
firebase deploy --only firestore:rules

# Validate rules (without deploying)
firebase deploy --only firestore:rules --dry-run
```

---

## Access Levels by Collection

### Public Read / Authenticated Write

```
/rooms/{roomId}                   # All signed-in users can read
/activity_feed/{activityId}       # All signed-in users can read
/posts/{postId}                   # All signed-in users can read
/conversations/{convId}           # Participants only
```

### Self-Only

```
/users/{userId}/privacy           # Self only
/users/{userId}/security          # Self + Admin only
/users/{userId}/wallet            # Self + Admin only
/users/{userId}/adult_profile     # Self + verified adults
/presence/{userId}                # Self writes, all read
/preferences/{userId}             # Self only
```

### Admin-Only

```
/reports/{reportId}               # Admin only
/entitlement_events/{eventId}     # Admin only
/roles/admins/{adminUid}          # Admin only
/verification/{userId}            # Self + Admin (no writes)
/wallets/{userId}                 # Self + Admin (no writes)
/transactions/{transactionId}     # Self + Admin (no writes)
```

### Host/Moderator Only

```
/rooms/{roomId}/speakers/{speakerId}          # Server-only writes
/rooms/{roomId}/mod_log/{entryId}             # Host creates, admin reads
/rooms/{roomId}/policies/{docId}              # Host can create/update
```

---

## Common Rules

### Only Host Can Modify Room

```
allow update: if signedIn() && resource.data.hostId == uid()
```

### Only Self Can Read/Write

```
allow read, write: if isSelf(userId)
```

### Server-Only (No Client Writes)

```
allow read: if signedIn();
allow create, update, delete: if false;
```

### Participants In Room

```
allow read: if isRoomParticipant(roomId, uid())
```

### Verified Adults Only

```
allow read: if isAdultVerified(uid())
```

### Conversation Participants Only

```
allow access: if isConversationParticipant(convData)
```

---

## Restricted Fields (Never Allow Client Write)

```dart
'admin'
'isAdmin'
'role'
'coins'
'coinBalance'
'cashBalance'
'wallet'
'email'
'isVerified'
'isAdultVerified'
'verificationStatus'
'adultModeEnabled'
```

---

## Common Mistakes

### ❌ Trusting Client-Side Flags

```dart
// WRONG: Client can fake being verified
if (userData['isAdultVerified']) { ... }

// RIGHT: Check server-managed verification doc
isAdultVerified(uid())
```

### ❌ Allowing Privilege Escalation

```dart
// WRONG: Client can promote themselves
allow update: if signedIn() && request.resource.data.role == 'admin'

// RIGHT: Server only manages roles
allow update: if signedIn() && request.resource.data.role == resource.data.role
```

### ❌ Weak Timestamp Validation

```dart
// WRONG: Can set any timestamp
allow create: if request.resource.data.createdAt is timestamp

// RIGHT: Must be current server time
allow create: if validTimestamp(request.resource.data.createdAt)
  where validTimestamp(ts) = ts == request.time && ts is timestamp
```

### ❌ Missing Field Whitelisting

```dart
// WRONG: Any fields allowed
allow create: if signedIn()

// RIGHT: Explicit whitelist only
allow create: if signedIn()
  && request.resource.data.keys().hasOnly(['name', 'bio', 'photoUrl'])
```

---

## Testing Rules Locally

### 1. Start Emulator

```bash
firebase emulators:start --only firestore
```

### 2. Connect to Emulator in Code

```dart
if (kDebugMode) {
  await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```

### 3. Write Tests

```dart
test('Host can create room', () async {
  // Test passes if rule allows, fails if denied
  final room = FirebaseFirestore.instance
    .collection('rooms')
    .doc('test-room')
    .set({'hostId': 'user123', ...});
  
  expect(room, isNotNull);
});
```

---

## Performance Tips

### 1. Use Indexes

Navigate to Firebase Console → Firestore → Indexes to create composite indexes for:
- `where('participantIds', arrayContains: uid).where('isLive', ==: true)`
- `where('hostId', ==: uid).where('createdAt', >, timestamp)`

### 2. Limit Query Results

```dart
// Good: Limited
.limit(20)

// Bad: No limit, could be thousands
.get()
```

### 3. Use Query Constraints

```dart
// Faster: Only get active rooms
.where('endedAt', ==: null)
.where('isLive', ==: true)

// Slower: Get all rooms, filter client-side
.get()
```

---

## Monitoring

### Check Rule Violations

Firebase Console → Firestore → Rules

```
- Review any recent denials
- Check if legitimate users are being blocked
- Verify admin operations succeed
```

### View Query Performance

Firebase Console → Firestore → Usage

```
- Read/write counts by collection
- Identify high-traffic collections
- Find expensive queries
```

---

## Emergency Procedures

### Temporarily Allow All (Debugging Only)

```dart
// DANGER: Use only for local testing
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // DEBUG ONLY!
    }
  }
}
```

### Block All Writes (Prevent Runaway Costs)

```dart
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

### Enable Audit Logging

Firebase Console → Firestore → Security Rules → View in Logs

---

## References

- [Official Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Common Rules Patterns](https://firebase.google.com/docs/firestore/security/rules-query)
- [Rule Structure](https://firebase.google.com/docs/firestore/security/rules-structure)

