# MIXVY Room Member Tracking Analysis
**Date:** June 29, 2026  
**Scope:** Understanding room join/leave logic, denormalized member fields, and discovery feed avatars

---

## Executive Summary

The codebase has **partial but incomplete** room member tracking:
- ✅ **Working**: Join/leave updates to `audienceUserIds` and `memberCount`
- ✅ **Working**: Discovery feed shows avatars via `RoomAvatarStack` 
- ⚠️ **Partial**: No visible logic for promoting users to `stageUserIds`
- ❌ **Missing**: No Cloud Functions to sync/repair denormalized fields
- ❌ **Missing**: Avatar URLs not passed to `RoomAvatarStack` widget

---

## 1. Files Handling Room Join/Leave Operations

### Primary Live Room Screen (NEW)
**File:** [lib/features/room/presentation/live_room_screen.dart](lib/features/room/presentation/live_room_screen.dart)

**Join Logic (Line 63-110):**
```dart
Future<void> _joinRoom(String uid, String username) async {
  // 1. Create participant doc
  await roomRef.collection('participants').doc(uid).set({
    'userId': uid,
    'role': 'audience',
    'userStatus': 'joined',
    'joinedAt': FieldValue.serverTimestamp(),
    'lastActiveAt': FieldValue.serverTimestamp(),
  });

  // 2. Update room document
  await roomRef.update({
    'audienceUserIds': FieldValue.arrayUnion([uid]),
    'memberCount': FieldValue.increment(1),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

**Leave Logic (Line 122-154):**
```dart
Future<void> _leaveRoom() async {
  // 1. Delete participant doc
  await roomRef.collection('participants').doc(currentUser.uid).delete();
  
  // 2. Update room document  
  await roomRef.update({
    'audienceUserIds': FieldValue.arrayRemove([currentUser.uid]),
    'memberCount': FieldValue.increment(-1),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

### Room Management Controller
**File:** [lib/features/room/controllers/room_management_controller.dart](lib/features/room/controllers/room_management_controller.dart)

**Member Removal (Line 384-410):**
```dart
Future<void> removeMember({
  required String roomId,
  required String userId,
}) async {
  // Removes from BOTH stage and audience lists
  await _firestore.collection('rooms').doc(roomId).update({
    'stageUserIds': FieldValue.arrayRemove([userId]),
    'audienceUserIds': FieldValue.arrayRemove([userId]),
    'memberCount': FieldValue.increment(-1),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  // Delete participant doc
  await _firestore
      .collection('rooms')
      .doc(roomId)
      .collection('participants')
      .doc(userId)
      .delete();
}
```

### Room Service (Creation)
**File:** [lib/services/room_service.dart](lib/services/room_service.dart) (Line 218-245)

**Room Creation Initialization:**
```dart
await docRef.set({
  'name': trimmedName,
  'stageUserIds': <String>[],
  'audienceUserIds': <String>[trimmedHostId],  // Host starts in audience
  'memberCount': 1,
  'category': category?.trim(),
  // ...
});
```

---

## 2. Current Implementation of Participant Count Tracking

### Denormalized Fields in RoomModel
**File:** [lib/models/room_model.dart](lib/models/room_model.dart)

```dart
class RoomModel {
  final List<String> stageUserIds;        // Users currently on mic/broadcasting
  final List<String> audienceUserIds;     // Users listening/in audience
  final int memberCount;                   // Total of both lists
  
  /// Combined members list (used by UI)
  List<String> get members => [
    ...stageUserIds,
    ...audienceUserIds,
  ];
}
```

### Firestore Rules Validation
**File:** [firestore.rules](firestore.rules) (Line 461)

The rules allow users to self-manage only their own presence:
```
&& request.resource.data.diff(resource.data).affectedKeys().hasOnly(
  ['audienceUserIds', 'stageUserIds', 'memberCount', 'updatedAt']
)
// If audienceUserIds changed, the diff must be exactly the caller's UID
&& (
  !request.resource.data.diff(resource.data).affectedKeys().hasAny(['audienceUserIds'])
  || (
    request.resource.data.audienceUserIds.removeAll(resource.data.audienceUserIds).hasOnly([uid()])
    || resource.data.audienceUserIds.removeAll(request.resource.data.audienceUserIds).hasOnly([uid()])
  )
)
```

### Live Room Card (Discovery Feed)
**File:** [lib/features/feed/widgets/live_room_card.dart](lib/features/feed/widgets/live_room_card.dart) (Line 26-29)

```dart
final speakerCount = room.stageUserIds.length;
final memberCount = room.memberCount > 0
    ? room.memberCount
    : room.stageUserIds.length + room.audienceUserIds.length;
```

Shows participant counts but with a **fallback calculation** if `memberCount` is 0.

---

## 3. Missing or Broken Logic

### 🔴 CRITICAL: No Stage Promotion Logic
**Issue:** There is NO visible code path that moves users from `audienceUserIds` → `stageUserIds`.

**Expected Flow (NOT IMPLEMENTED):**
```dart
// When host invites user to stage or user requests mic:
// ❌ Missing: Remove from audienceUserIds
// ❌ Missing: Add to stageUserIds
// ❌ Missing: Update participant role to 'stage'
```

**Current State:** Only `hostControls.promoteToCohost()` and similar role updates exist, but they only update the `participants/{userId}` doc, NOT the room's denormalized lists.

### 🔴 CRITICAL: No Cloud Function Triggers
**File:** [functions/index.js](functions/index.js)

Searched entire functions file. Found:
- ✅ Direct call room notifications
- ✅ Gift sending functions
- ✅ Payment processing
- ❌ **NO triggers for room participant changes**
- ❌ **NO automatic denormalization sync**
- ❌ **NO healing when participant counts get out of sync**

**What Should Exist:**
```javascript
// onDocumentWritten('rooms/{roomId}/participants/{userId}', ...)
// - Increment/decrement audienceUserIds on participant create/delete
// - Move between stageUserIds/audienceUserIds based on role changes
// - Update memberCount
// - Handle stale participant cleanup
```

### 🟡 PARTIAL: No Real-Time Participant Role Sync
**Current Flow:**
1. User role is stored in `participants/{userId}` subcollection
2. Room document has `stageUserIds` and `audienceUserIds`
3. **No code updates room lists when role changes in participants doc**

**Providers:** [lib/features/room/providers/participant_providers.dart](lib/features/room/providers/participant_providers.dart)
- ✅ Watches `participants` subcollection
- ✅ Calculates if participant is "fresh" (joined in last 30 min)
- ❌ Does NOT update room's stage/audience lists

### 🟡 PARTIAL: RoomAvatarStack Not Getting Avatar URLs
**File:** [lib/features/room/widgets/room_avatar_stack.dart](lib/features/room/widgets/room_avatar_stack.dart)

**Widget Definition:**
```dart
class RoomAvatarStack extends StatelessWidget {
  final List<String> uids;
  final List<String> avatarUrls = const [];  // Empty!
}
```

**Usage in Discovery Feed:** [lib/features/feed/screens/discovery_feed_screen.dart](lib/features/feed/screens/discovery_feed_screen.dart) (Line 2301-2303)
```dart
RoomAvatarStack(
  uids: clusterUids,
  // ❌ avatarUrls parameter NEVER set - always uses empty list
  // Comment says: "Using denormalized data if available..."
  // But NO denormalized avatar URLs exist in RoomModel
)
```

**Result:** Avatars show as gray circles instead of actual user photos.

---

## 4. Discovery Feed Avatar Implementation

### Current Implementation
**File:** [lib/features/feed/screens/discovery_feed_screen.dart](lib/features/feed/screens/discovery_feed_screen.dart)

**Avatar Clustering Logic (Line 2215-2232):**
```dart
List<String> _clusterUids() {
  final seen = <String>{};
  final uids = <String>[];
  
  // Take top 4 live rooms
  for (final room in liveRooms.take(4)) {
    // Collect up to 4 unique user IDs from stage + audience
    for (final uid in [...room.stageUserIds, ...room.audienceUserIds]) {
      if (seen.add(uid)) {
        uids.add(uid);
        if (uids.length >= 4) return uids;
      }
    }
    
    // Fallback: use host ID
    if (seen.add(room.hostId)) {
      uids.add(room.hostId);
      if (uids.length >= 4) return uids;
    }
  }
  return uids;
}
```

**Display Location:**
```dart
RoomAvatarStack(
  uids: clusterUids,  // User IDs only, no avatar URLs
)
```

### What "Who's in the Room" Shows

**In Discovery Feed:**
- ✅ Shows up to 4 user avatars from most active rooms
- ✅ Avatar stack draws from `stageUserIds` + `audienceUserIds`
- ✅ Falls back to `hostId` if insufficient participants
- ❌ Avatar circles are gray (no image URLs)
- ❌ No names or roles shown
- ❌ No indication of who's speaking vs listening

**In Live Room Card:**
```dart
// Line 26-29: Just shows counts
final speakerCount = room.stageUserIds.length;
final memberCount = room.memberCount > 0 ? room.memberCount : ...;
```

---

## 5. Data Schema Integrity Issues

### Room Document Schema
**Current Fields:**
```json
{
  "id": "room-123",
  "stageUserIds": ["user-1", "user-2"],      // Who's broadcasting
  "audienceUserIds": ["user-3", "user-4"],   // Who's listening
  "memberCount": 4,                           // Denormalized count
  "hostId": "user-1",
  "hostAvatarUrl": "...",                     // Only host avatar stored
  "updatedAt": "...",
  "participants": {
    "user-1": {
      "userId": "user-1",
      "role": "host",
      "isMuted": false,
      "joinedAt": "..."
    },
    ...
  }
}
```

**Missing Denormalization:**
- No `stageUserAvatarUrls` array
- No `audienceUserAvatarUrls` array  
- No `stageUserDisplayNames` array
- Only `hostAvatarUrl` is stored (why?)

---

## 6. Firestore Sync Issues & Repair Strategies

### Potential Out-of-Sync Scenarios

| Scenario | Cause | Impact |
|----------|-------|--------|
| Extra IDs in `audienceUserIds` | Client crashes after adding ID but before cleanup | User shown as present when offline |
| Missing IDs in `audienceUserIds` | Participant doc deleted but room not updated | User not visible; member count wrong |
| `memberCount` ≠ `stageUserIds.length + audienceUserIds.length` | Network interruption between operations | Discovery feed shows wrong counts |
| User in both `stageUserIds` AND `audienceUserIds` | Role change race condition | User appears in two places |
| Old participant docs with no matching room entry | App crashed after leaving | Orphaned data consuming quota |

### What's Currently Missing

**No Healing Mechanism:**
```dart
// ❌ Does NOT exist: Function to verify room integrity
repairRoomMemberLists(roomId);

// ❌ Does NOT exist: Cleanup stale participants
cleanupOrphanedParticipants(roomId);

// ❌ Does NOT exist: Cloud Function on schedule
scheduledRoomIntegrityCheck();
```

**No Conflict Resolution:**
```dart
// ❌ When role is updated in participants doc:
// - stageUserIds is NOT automatically updated
// - audienceUserIds is NOT automatically updated
// - memberCount stays the same
```

---

## 7. Required Changes for "Who's in the Room" to Work End-to-End

### Phase 1: Add Denormalization to Room Document

**File to modify:** [lib/services/room_service.dart](lib/services/room_service.dart)

```dart
// When creating room:
await docRef.set({
  'stageUserIds': <String>[],
  'stageUserDisplayNames': <String>[],
  'stageUserAvatarUrls': <String>[],
  'audienceUserIds': <String>[],
  'audienceUserDisplayNames': <String>[],
  'audienceUserAvatarUrls': <String>[],
  'memberCount': 1,
  // ...
});
```

### Phase 2: Create Cloud Function Triggers

**File:** [functions/index.js](functions/index.js) - ADD:

```javascript
// When participant doc is created
exports.onParticipantJoined = onDocumentCreated(
  'rooms/{roomId}/participants/{userId}',
  async (event) => {
    const roomId = event.params.roomId;
    const userId = event.params.userId;
    const participant = event.data.data();
    
    // 1. Get user display name and avatar
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const displayName = userDoc.data()?.displayName || userId;
    const avatarUrl = userDoc.data()?.avatarUrl || '';
    
    // 2. Add to appropriate room list based on role
    const role = participant.role || 'audience';
    if (role === 'stage' || role === 'host' || role === 'cohost') {
      await admin.firestore().collection('rooms').doc(roomId).update({
        'stageUserIds': admin.firestore.FieldValue.arrayUnion([userId]),
        'stageUserDisplayNames': admin.firestore.FieldValue.arrayUnion([displayName]),
        'stageUserAvatarUrls': admin.firestore.FieldValue.arrayUnion([avatarUrl]),
        'memberCount': admin.firestore.FieldValue.increment(1),
      });
    } else {
      await admin.firestore().collection('rooms').doc(roomId).update({
        'audienceUserIds': admin.firestore.FieldValue.arrayUnion([userId]),
        'audienceUserDisplayNames': admin.firestore.FieldValue.arrayUnion([displayName]),
        'audienceUserAvatarUrls': admin.firestore.FieldValue.arrayUnion([avatarUrl]),
        'memberCount': admin.firestore.FieldValue.increment(1),
      });
    }
  }
);

// When participant role changes
exports.onParticipantRoleChanged = onDocumentWritten(
  'rooms/{roomId}/participants/{userId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    
    if (before?.role === after?.role) return; // No role change
    
    // Move user between lists...
  }
);

// When participant leaves
exports.onParticipantLeft = onDocumentDeleted(
  'rooms/{roomId}/participants/{userId}',
  async (event) => {
    // Remove from both lists, decrement memberCount
  }
);
```

### Phase 3: Update RoomAvatarStack to Use URLs

**File:** [lib/features/room/widgets/room_avatar_stack.dart](lib/features/room/widgets/room_avatar_stack.dart)

```dart
class RoomAvatarStack extends StatelessWidget {
  final List<String> uids;
  final List<String> avatarUrls;  // NOW REQUIRED
  
  // Fetch avatar URLs from user documents when not provided
  FutureBuilder<List<String>> _getAvatarUrls() { ... }
}
```

### Phase 4: Update Discovery Feed to Pass URLs

**File:** [lib/features/feed/screens/discovery_feed_screen.dart](lib/features/feed/screens/discovery_feed_screen.dart) (Line 2301)

```dart
List<String> _clusterAvatarUrls() {
  final avatarUrls = <String>[];
  // Get from denormalized stageUserAvatarUrls + audienceUserAvatarUrls
  for (final room in liveRooms.take(4)) {
    avatarUrls.addAll(
      [...room.stageUserAvatarUrls, ...room.audienceUserAvatarUrls]
        .take(4 - avatarUrls.length)
    );
    if (avatarUrls.length >= 4) break;
  }
  return avatarUrls;
}

// Then use:
RoomAvatarStack(
  uids: clusterUids,
  avatarUrls: _clusterAvatarUrls(),  // ← ADD THIS
)
```

---

## 8. Firestore Rules Changes

**Current Issue:** Rules allow `arrayUnion`/`arrayRemove` only if the change is exactly the caller's UID. This means client code cannot reliably move users between lists.

**Required Change:** Add Cloud Function as trusted writer that bypasses these restrictions.

---

## 9. Testing Checklist

- [ ] User can join room → `audienceUserIds` updated + `memberCount` incremented
- [ ] User can leave room → `audienceUserIds` updated + `memberCount` decremented
- [ ] Host promotes user to stage → User moves to `stageUserIds` (currently MISSING)
- [ ] User in `stageUserIds` shows in discovery feed avatars
- [ ] Discovery feed shows actual avatar images (not gray circles)
- [ ] Participant counts accurate after rapid joins/leaves
- [ ] Orphaned participant docs cleaned up after 1 hour
- [ ] Room member lists repair on every room load

---

## Summary Table

| Feature | Status | Location | Issue |
|---------|--------|----------|-------|
| Join room | ✅ Working | `live_room_screen.dart:63` | Uses `audienceUserIds` only |
| Leave room | ✅ Working | `live_room_screen.dart:122` | Uses `audienceUserIds` only |
| Promote to stage | ❌ Missing | - | No code path exists |
| Discovery feed avatars | ⚠️ Partial | `discovery_feed_screen.dart:2301` | Shows UIDs not images |
| RoomAvatarStack widget | ✅ Exists | `room_avatar_stack.dart` | Never receives avatar URLs |
| Cloud Function sync | ❌ Missing | `functions/index.js` | No triggers for member updates |
| Denormalized avatar URLs | ❌ Missing | `room_model.dart` | Only host avatar stored |
| Healing/repair logic | ❌ Missing | - | No integrity checks |

