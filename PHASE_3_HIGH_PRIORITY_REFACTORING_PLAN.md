# Phase 3: High-Priority Refactoring Plan

**Status:** Ready for Implementation
**Date:** 2026-06-25
**Scope:** 5 critical features blocking full deployment

---

## 1. Friend Blocking & Safety System

### Current State
- `isBlockedByMeProvider` returns hardcoded `false`
- `blockingFunctionality` not implemented in FriendService
- No block-checking in mutual friends, suggestions, or message flows

### What This Blocks
- ✋ Users cannot block harassers
- 🚨 Safety features incomplete
- 🔓 Moderation cannot enforce blocks

### Implementation Plan

#### Step 1: Update UserProfile Model
```dart
// lib/shared/models/user_profile.dart
@freezed
class UserProfile {
  // ... existing fields ...

  /// IDs of users blocked by this user
  final Set<String> blockedUserIds = const {};

  /// IDs of users who have blocked this user
  final Set<String> blockedByUserIds = const {};

  /// Timestamp of last block action
  final DateTime? lastBlockTime;
}
```

#### Step 2: Implement FriendService Methods
```dart
// lib/services/social/friend_service.dart

/// Block a user
Future<void> blockUser(String currentUserId, String targetUserId) async {
  final userRef = firestore.collection('users').doc(currentUserId);
  await userRef.update({
    'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
    'lastBlockTime': FieldValue.serverTimestamp(),
  });

  // Optionally: Log block action for moderation
  await firestore.collection('moderation_logs').add({
    'action': 'block',
    'initiator': currentUserId,
    'target': targetUserId,
    'timestamp': FieldValue.serverTimestamp(),
  });
}

/// Check if user is blocked
Stream<bool> isUserBlocked(String currentUserId, String targetUserId) {
  return firestore.collection('users').doc(currentUserId).snapshots()
    .map((doc) {
      final blockedIds = List<String>.from(doc['blockedUserIds'] ?? []);
      return blockedIds.contains(targetUserId);
    });
}

/// Get list of blocked users
Stream<List<String>> getBlockedUsers(String userId) {
  return firestore.collection('users').doc(userId).snapshots()
    .map((doc) => List<String>.from(doc['blockedUserIds'] ?? []));
}
```

#### Step 3: Update Providers
```dart
// lib/shared/providers/friend_request_provider.dart

/// ✅ FIXED: Real block checking
final isBlockedByMeProvider = StreamProvider.family<bool, String>((ref, targetUserId) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value(false);

  return ref.read(friendServiceProvider).isUserBlocked(currentUser.id, targetUserId);
});

/// Get list of users I've blocked
final myBlockedUsersProvider = StreamProvider<List<String>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);

  return ref.read(friendServiceProvider).getBlockedUsers(currentUser.id);
});
```

#### Step 4: Add Block UI Actions
```dart
// lib/shared/widgets/user_action_menu.dart
// Add buttons for:
// - "Block User"
// - "Report User"
// - "Message User" (disabled if blocked)
```

#### Step 5: Enforce Blocks in Message/Friend Flows
```dart
// Before sending message
final isBlocked = await ref.read(isBlockedByMeProvider(targetUserId).future);
if (isBlocked) {
  showError('User is blocked');
  return;
}

// Before showing in friend suggestions
final blocked = await ref.read(myBlockedUsersProvider.future);
final suggestions = suggestions.where((u) => !blocked.contains(u.id));
```

### Files to Modify
- `lib/shared/models/user_profile.dart` — Add block tracking
- `lib/services/social/friend_service.dart` — Implement block logic
- `lib/shared/providers/friend_request_provider.dart` — Update providers
- `lib/features/messaging/` — Enforce blocks before sending
- `lib/features/social/` — Add block UI actions

### Effort Estimate: **2-3 hours**

---

## 2. Location-Based Features (Events & Matching)

### Current State
- `event_dating_providers.dart` has 2 TODOs for location filtering
- `matching_profile.dart` has latitude/longitude but no distance queries
- No geohashing or spatial indexing
- Location permission not requested

### What This Blocks
- 📍 Events cannot be filtered by proximity
- 🧭 Matching cannot use location as signal
- 🚀 Discovery is non-localized

### Implementation Plan

#### Step 1: Add Location Permission Request
```dart
// lib/core/utils/permissions_manager.dart
Future<bool> requestLocationPermission() async {
  final status = await Permission.location.request();
  return status.isGranted;
}

// Use in onboarding or profile setup
await permissionsManager.requestLocationPermission();
```

#### Step 2: Add Location Services
```dart
// lib/services/location/location_service.dart
import 'geolocator/geolocator.dart';

class LocationService {
  /// Get current user location
  Future<({double latitude, double longitude})> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    return (latitude: position.latitude, longitude: position.longitude);
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
```

#### Step 3: Update Event Model & Providers
```dart
// lib/shared/models/event.dart
@freezed
class Event {
  factory Event({
    required String id,
    required String title,
    required double latitude,
    required double longitude,
    required DateTime startTime,
    // ... other fields
  }) = _Event;
}

// lib/shared/providers/event_dating_providers.dart
final userLocationProvider = FutureProvider<({double latitude, double longitude})>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return locationService.getCurrentLocation();
});

final nearbyEventsProvider = FutureProvider.family<List<Event>, double>(
  (ref, radiusInMiles) async {
    final userLocation = await ref.watch(userLocationProvider.future);
    final allEvents = await ref.read(eventServiceProvider).getUpcomingEvents();

    final locationService = ref.read(locationServiceProvider);
    return allEvents.where((event) {
      final distance = locationService.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        event.latitude,
        event.longitude,
      );
      return distance <= radiusInMiles;
    }).toList();
  },
);
```

#### Step 4: Add UI for Location Filtering
```dart
// lib/features/events/screens/events_screen.dart
// Add slider for distance radius (5 mi → 50 mi)
// Show distance on event card
// Sort by proximity
```

#### Step 5: Update Matching Logic
```dart
// lib/services/matching/matching_service.dart
Future<List<MatchResult>> getLocationBasedMatches(String userId, {double radiusMiles = 25}) async {
  final user = await getUser(userId);
  final candidates = await getCandidates();

  return candidates
    .where((candidate) {
      final distance = calculateDistance(
        user.latitude, user.longitude,
        candidate.latitude, candidate.longitude,
      );
      return distance <= radiusMiles;
    })
    .map((c) => MatchResult(user: c, score: calculateScore(user, c)))
    .sorted((a, b) => b.score.compareTo(a.score))
    .toList();
}
```

### Files to Modify
- `lib/services/location/location_service.dart` — Create location service
- `lib/shared/models/event.dart` — Add lat/lon
- `lib/shared/providers/event_dating_providers.dart` — Real location filtering
- `lib/services/matching/matching_service.dart` — Add location-based matching
- `lib/features/events/screens/events_screen.dart` — Add distance UI
- `android/app/AndroidManifest.xml` — Add location permission
- `ios/Runner/Info.plist` — Add location permission

### Dependencies
- `geolocator` package (likely already in pubspec)
- `permission_handler` (already added in Phase 2)

### Effort Estimate: **3-4 hours**

---

## 3. Media Uploads for Chat (Image/Video/File)

### Current State
- `chat_room_page.dart` has 3 TODOs for media uploads
- Media picker UI exists but handlers not implemented
- No storage integration

### What This Blocks
- 🖼️ Cannot send images in chat
- 🎥 Cannot share video clips
- 📄 Cannot share files

### Implementation Plan

#### Step 1: Implement Media Upload Handler
```dart
// lib/services/chat/media_chat_service.dart
import 'package:image_picker/image_picker.dart';

class MediaChatService {
  final StorageService _storage = StorageService();

  /// Upload image to storage and return URL
  Future<String?> uploadChatImage(String userId, String roomId, XFile image) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = 'chat/$roomId/images/$fileName';

      final url = await _storage.uploadFile(
        filePath: image.path,
        storagePath: path,
      );

      return url;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Upload video with thumbnail
  Future<({String videoUrl, String thumbnailUrl})?> uploadChatVideo(
    String userId,
    String roomId,
    XFile video,
  ) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${video.name}';
      const path = 'chat/$roomId/videos/$fileName';

      // Upload video
      final videoUrl = await _storage.uploadFile(
        filePath: video.path,
        storagePath: path,
      );

      // Generate and upload thumbnail
      final thumbnail = await _generateVideoThumbnail(video);
      if (thumbnail != null) {
        final thumbnailUrl = await _storage.uploadFile(
          filePath: thumbnail,
          storagePath: 'chat/$roomId/thumbnails/${fileName}_thumb',
        );
        return (videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
      }

      return (videoUrl: videoUrl, thumbnailUrl: '');
    } catch (e) {
      debugPrint('Error uploading video: $e');
      return null;
    }
  }
}
```

#### Step 2: Update Chat Message Model
```dart
// lib/shared/models/message.dart
@freezed
class Message {
  factory Message({
    required String id,
    required String senderId,
    required String content,
    required DateTime timestamp,
    required String roomId,

    // Media fields
    String? mediaUrl,
    String? mediaType, // 'image', 'video', 'file'
    String? thumbnailUrl, // for videos
    String? fileName, // for files
    ({double width, double height})? mediaDimensions,
  }) = _Message;
}
```

#### Step 3: Update Chat Service
```dart
// lib/services/chat/messaging_service.dart
Future<void> sendMediaMessage({
  required String roomId,
  required String senderId,
  required String mediaUrl,
  required String mediaType,
  String? thumbnailUrl,
}) async {
  final message = Message(
    id: const Uuid().v4(),
    senderId: senderId,
    content: '[${mediaType.toUpperCase()}]',
    timestamp: DateTime.now(),
    roomId: roomId,
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    thumbnailUrl: thumbnailUrl,
  );

  await firestore.collection('rooms').doc(roomId)
    .collection('messages').doc(message.id).set(message.toMap());
}
```

#### Step 4: Implement Chat UI Handlers
```dart
// lib/features/chat_room_page.dart
Future<void> _sendImageMessage() async {
  final imagePicker = ImagePicker();
  final image = await imagePicker.pickImage(source: ImageSource.gallery);

  if (image == null) return;

  // Show loading
  showLoadingDialog('Uploading image...');

  try {
    final imageUrl = await ref.read(mediaChatServiceProvider)
      .uploadChatImage(currentUser.id, roomId, image);

    if (imageUrl != null) {
      await ref.read(messagingServiceProvider).sendMediaMessage(
        roomId: roomId,
        senderId: currentUser.id,
        mediaUrl: imageUrl,
        mediaType: 'image',
      );
    }
  } finally {
    dismissLoadingDialog();
  }
}

Future<void> _sendVideoMessage() async {
  final videoPicker = ImagePicker();
  final video = await videoPicker.pickVideo(source: ImageSource.gallery);

  if (video == null) return;

  showLoadingDialog('Uploading video...');

  try {
    final result = await ref.read(mediaChatServiceProvider)
      .uploadChatVideo(currentUser.id, roomId, video);

    if (result != null) {
      await ref.read(messagingServiceProvider).sendMediaMessage(
        roomId: roomId,
        senderId: currentUser.id,
        mediaUrl: result.videoUrl,
        mediaType: 'video',
        thumbnailUrl: result.thumbnailUrl,
      );
    }
  } finally {
    dismissLoadingDialog();
  }
}
```

#### Step 5: Add Media Display in Chat Bubble
```dart
// lib/shared/widgets/message_bubble.dart
// Display image/video/file based on message.mediaType
// Show thumbnail for videos with play button
// Show file icon with name for documents
```

### Files to Modify
- `lib/services/chat/media_chat_service.dart` — Create media service
- `lib/shared/models/message.dart` — Add media fields
- `lib/services/chat/messaging_service.dart` — Add media sending
- `lib/features/chat_room_page.dart` — Implement upload handlers
- `lib/shared/widgets/message_bubble.dart` — Display media
- `pubspec.yaml` — Add `video_thumbnail` package (if not present)

### Dependencies
- `image_picker` (likely already present)
- `video_thumbnail` (for video thumbnails)
- `path_provider` (for temp storage)

### Effort Estimate: **4-5 hours**

---

## 4. Account Settings Flows

### Current State
- `account_settings_page.dart` has 4 TODOs
- Change email, change password, OAuth linking all stubbed

### What This Blocks
- 🔐 Users cannot update email
- 🔑 Users cannot change password
- 🔗 OAuth login integration incomplete

### Implementation Plan

#### Step 1: Implement Email Change
```dart
// lib/services/auth/auth_service.dart
Future<void> changeEmail(String currentPassword, String newEmail) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not authenticated');

  // Re-authenticate with current password
  final credential = EmailAuthProvider.credential(
    email: user.email!,
    password: currentPassword,
  );
  await user.reauthenticateWithCredential(credential);

  // Update email
  await user.verifyBeforeUpdateEmail(newEmail);

  // Update user profile in Firestore
  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
    'email': newEmail,
    'emailVerified': false,
    'lastEmailChange': FieldValue.serverTimestamp(),
  });
}
```

#### Step 2: Implement Password Change
```dart
// lib/services/auth/auth_service.dart
Future<void> changePassword(String currentPassword, String newPassword) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not authenticated');

  // Re-authenticate
  final credential = EmailAuthProvider.credential(
    email: user.email!,
    password: currentPassword,
  );
  await user.reauthenticateWithCredential(credential);

  // Update password
  await user.updatePassword(newPassword);

  // Log action for security
  await FirebaseFirestore.instance.collection('user_security_logs').add({
    'userId': user.uid,
    'action': 'password_changed',
    'timestamp': FieldValue.serverTimestamp(),
  });
}
```

#### Step 3: Implement OAuth Linking
```dart
// lib/services/auth/oauth_service.dart
Future<void> linkGoogleAccount(String userId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not authenticated');

  try {
    final googleSignIn = GoogleSignIn();
    final googleAccount = await googleSignIn.signIn();

    if (googleAccount != null) {
      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.linkWithCredential(credential);

      // Update user profile
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'linkedProviders': FieldValue.arrayUnion(['google']),
      });
    }
  } catch (e) {
    debugPrint('Error linking Google: $e');
    rethrow;
  }
}

Future<void> linkFacebookAccount(String userId) async {
  // Similar implementation for Facebook
}
```

#### Step 4: Create Account Settings Provider
```dart
// lib/shared/providers/account_settings_provider.dart
final changeEmailProvider = FutureProvider.family<void, Map<String, dynamic>>(
  (ref, params) async {
    final authService = ref.read(authServiceProvider);
    await authService.changeEmail(
      params['currentPassword'],
      params['newEmail'],
    );
  },
);

final changePasswordProvider = FutureProvider.family<void, Map<String, dynamic>>(
  (ref, params) async {
    final authService = ref.read(authServiceProvider);
    await authService.changePassword(
      params['currentPassword'],
      params['newPassword'],
    );
  },
);

final linkOAuthProvider = FutureProvider.family<void, String>(
  (ref, provider) async {
    final userId = ref.watch(currentUserProvider).value?.id ?? '';
    final oauthService = ref.read(oauthServiceProvider);

    if (provider == 'google') {
      await oauthService.linkGoogleAccount(userId);
    } else if (provider == 'facebook') {
      await oauthService.linkFacebookAccount(userId);
    }
  },
);
```

#### Step 5: Implement UI
```dart
// lib/features/settings/account_settings_page.dart
// Add sections for:
// - Email management (show current, change button)
// - Password change (current + new + confirm)
// - OAuth linking (buttons for Google, Facebook)
// - Security log (recent changes)
```

### Files to Modify
- `lib/services/auth/auth_service.dart` — Add email/password methods
- `lib/services/auth/oauth_service.dart` — Create OAuth linking
- `lib/shared/providers/account_settings_provider.dart` — Add providers
- `lib/features/settings/account_settings_page.dart` — Implement UI

### Dependencies
- `google_sign_in` (likely already present)
- `flutter_facebook_auth` (may need to add)

### Effort Estimate: **3-4 hours**

---

## 5. Audit & Fix N+1 Query Risk

### Current State
- `mutualFriendsProvider` makes O(n) Firestore reads per profile
- Friend suggestions also have N+1 pattern

### What This Blocks
- ⚠️ Potential for high Firestore quota usage
- 🐌 Slow profile page loads with many profiles

### Implementation Plan

#### Issue Analysis
```dart
// ❌ BAD: Calls getStreams once per mutual friend
final mutualFriendsProvider = FutureProvider.family<List<String>, String>((ref, otherUserId) async {
  final myFriends = await ref.watch(friendIdsProvider.future); // 1 read
  final theirFriends = await service.streamFriends(otherUserId).first; // 2 reads

  for (final friendId in myFriends.take(20)) {
    final theirFriends = await svc.streamFriends(friendId).first; // 20 reads!
    // ...
  }
});
```

#### Solution 1: Batch Queries
```dart
// ✅ GOOD: Use batch or collection group query
final mutualFriendsProvider = FutureProvider.family<List<String>, String>((ref, otherUserId) async {
  final myFriends = await ref.watch(friendIdsProvider.future);
  if (myFriends.isEmpty) return [];

  // Batch reads: get multiple docs in one call
  final batch = FirebaseFirestore.instance;
  final theirFriendsSnaps = await batch
    .getDocuments(friendIds: myFriends.take(20).toList());

  // Process batch results
  final mutual = <String>{};
  for (final snap in theirFriendsSnaps) {
    final friendIds = snap['friendIds'] as List? ?? [];
    mutual.addAll(friendIds.cast<String>());
  }

  return mutual.where((f) => myFriends.contains(f)).toList();
});
```

#### Solution 2: Denormalize Friend Count
```dart
// Cache friend count + top 20 on user profile
@freezed
class UserProfile {
  final int friendCount;
  final List<String> topFriendIds; // Top 20 for quick display
}

// Updates when friend list changes
// Reduces need to fetch every friend to calculate mutual
```

#### Solution 3: Implement Caching
```dart
// lib/services/social/friend_cache_service.dart
class FriendCacheService {
  final _cache = <String, List<String>>{};
  final _expiry = <String, DateTime>{};

  Future<List<String>> getCachedFriends(String userId) async {
    if (_isExpired(userId)) {
      final friends = await _fetchFriends(userId);
      _cache[userId] = friends;
      _expiry[userId] = DateTime.now().add(Duration(minutes: 5));
    }
    return _cache[userId] ?? [];
  }
}
```

### Files to Modify
- `lib/shared/providers/friend_request_provider.dart` — Optimize mutual friends
- `lib/services/social/friend_service.dart` — Add batch methods
- `lib/shared/models/user_profile.dart` — Add denormalized fields

### Effort Estimate: **1-2 hours** (audit + optimize high-use queries)

---

## Summary & Priority

| Feature | Effort | Impact | Priority |
|---------|--------|--------|----------|
| **1. Friend Blocking** | 2-3h | 🔴 Safety | P0 |
| **2. Location Features** | 3-4h | 🟠 UX | P1 |
| **3. Media Uploads** | 4-5h | 🟠 UX | P1 |
| **4. Account Settings** | 3-4h | 🟡 Nice-to-have | P2 |
| **5. Query Optimization** | 1-2h | 🟢 Tech debt | P2 |
| **TOTAL** | **13-18h** | | |

---

## Recommended Execution Order

**Week 1:**
- [ ] Friend Blocking (safety must ship first)
- [ ] Location Features (enables discovery)

**Week 2:**
- [ ] Media Uploads (completes chat)
- [ ] Account Settings (completes auth flows)

**Week 3+:**
- [ ] Query Optimization (ongoing performance)

---

## Success Metrics

After completing this plan:
- ✅ No blocking TODOs remain
- ✅ Safety features (blocking) functional
- ✅ Social discovery (location + blocking) fully enabled
- ✅ Chat feature parity (media support)
- ✅ Account management complete
- ✅ Firestore quota optimized
- ✅ Ready for production launch
