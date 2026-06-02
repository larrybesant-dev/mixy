// # MixVy Stream Registry
//
// **ONE RULE: ONE FEATURE = ONE STREAM SOURCE.**
//
// Every live Firestore stream in the app must be listed here.
// Any provider that opens a `.snapshots()` call directly MUST delegate
// through the canonical provider listed in this registry.
//
// ## How to use
//
// 1. Before adding a new StreamProvider:
//    - Check this registry. If a stream for this domain already exists, use it.
//    - Never open a second `.snapshots()` for the same collection + filter.
//
// 2. After adding a new canonical stream:
//    - Add it to the registry below.
//    - Add a static assertion in [StreamRegistryAssertions] so the analyzer
//      catches future duplicates at test time.
//
// ## Enforcement
//
// Run `flutter test lib/core/architecture/stream_registry_test.dart` to
// verify no duplicate streams are active in the provider graph.
//
// ## Registry (alphabetical by domain)
//
// Format: Domain | Canonical provider | Lifecycle | Fanout risk | File
//
// | Domain           | Canonical provider                        | Lifecycle      | Fanout | File                                              |
// |------------------|-------------------------------------------|----------------|--------|---------------------------------------------------|
// | Conversations    | rawConversationsStreamProvider            | autoDispose    | 🟢 1   | features/messaging/providers/messaging_provider.dart |
// | Conversations    | conversationsStreamProvider (derived)     | autoDispose    | 🟢 0   | features/messaging/providers/messaging_provider.dart |
// | Conversations    | requestsStreamProvider (derived)          | autoDispose    | 🟢 0   | features/messaging/providers/messaging_provider.dart |
// | Conversations    | schemaConversationsProvider               | autoDispose    | 🟡 2†  | features/schema_messenger/messages/providers/        |
// | Conversation doc | conversationDocProvider                   | autoDispose    | 🟢 1   | features/messaging/providers/messaging_provider.dart |
// | Messages         | messagesStreamProvider                    | autoDispose    | 🟢 1   | features/messaging/providers/messaging_provider.dart |
// | Follow graph     | rawFollowGraphStreamProvider              | autoDispose    | 🟢 1   | features/follow/providers/follow_provider.dart       |
// | Follower IDs     | rawFollowerIdsStreamProvider              | autoDispose    | 🟢 1   | features/follow/providers/follow_provider.dart       |
// | Friendships      | rawAllFriendshipsStreamProvider (all)     | autoDispose    | 🟢 3   | features/friends/providers/friends_providers.dart    |
// | Friendships      | rawAcceptedFriendshipsStreamProvider      | autoDispose    | 🟢 4‡  | features/friends/providers/friends_providers.dart    |
// | Friendships      | friendsProvider (derived)                 | autoDispose    | 🟢 0   | features/friends/providers/friends_providers.dart    |
// | Friendships      | friendsListProvider (derived+users)       | autoDispose    | 🟢 0+1 | features/friends/providers/friends_providers.dart    |
// | Friendships      | friendRosterProvider (derived+users+pres) | autoDispose    | 🟢 0+2 | features/friends/providers/friends_providers.dart    |
// | Friendships      | schemaFriendLinksProvider (derived)       | autoDispose    | 🟢 0   | features/schema_messenger/friends/providers/         |
// | Friendships      | incomingFriendRequestsProvider (derived)  | autoDispose    | 🟢 0   | features/friends/providers/friends_providers.dart    |
// | Friendships      | pendingOutgoingFriend... (derived)        | autoDispose    | 🟢 0   | features/friends/providers/friends_providers.dart    |
// | Room doc         | roomDocStreamProvider                     | autoDispose    | 🟢 1   | features/room/providers/participant_providers.dart   |
// | Room doc (typed) | feedRoomStreamProvider (derived)          | autoDispose    | 🟢 0   | features/feed/providers/host_controls_providers.dart |
// | Participants     | participantsStreamProvider                | autoDispose    | 🟢 1   | features/room/providers/participant_providers.dart   |
// | Cohosts          | coHostsProvider (derived)                 | autoDispose    | 🟢 0   | features/room/providers/participant_providers.dart   |
// | Participant cnt  | participantCountProvider (derived)        | autoDispose    | 🟢 0   | features/room/providers/participant_providers.dart   |
// | Live rooms list  | roomsStreamProvider                       | autoDispose    | 🟢 1   | features/feed/providers/feed_providers.dart          |
// | Notifications    | notificationsStreamProvider               | global⚠        | 🟢 1   | presentation/providers/notification_provider.dart    |
// | Presence         | presenceStreamProvider (RTDB)             | autoDispose    | 🟢 1   | services/presence_repository.dart                   |
// | Typing           | typingStreamProvider                      | autoDispose    | 🟢 1   | features/feed/providers/typing_providers.dart        |
// | Reactions        | reactionsStreamProvider                   | autoDispose    | 🟢 1   | features/feed/providers/reaction_providers.dart      |
// | Verification     | userVerificationProvider (per-user)       | autoDispose    | 🟢 1   | features/verification/providers/verification_provider.dart |
// | Verified list    | verifiedUsersProvider (admin only)        | autoDispose    | 🟢 1   | features/verification/providers/verification_provider.dart |
// | User posts       | userPostsStreamProvider (per-user)        | autoDispose    | 🟢 1   | features/feed/providers/feed_providers.dart          |
//
// ‡ rawAcceptedFriendshipsStreamProvider opens 4 streams: userA+accepted,
//   userB+accepted, friend_links+accepted, plus user-doc friends-array fallback
//   for legacy data compatibility. All are inside watchAcceptedFriendships().
//   Riverpod family deduplication means one instance per userId regardless of
//   how many derived providers (friendsProvider, friendsListProvider,
//   friendRosterProvider) are simultaneously mounted.
//
//   rawConversationsStreamProvider when both panels are mounted. This is the
//   remaining duplication to consolidate (see TODO: schema conversation merge).
//
// ⚠ notificationsStreamProvider is intentionally global (badge count must
//   survive navigation) but is now limited to 50 docs. This is documented
//   intentional behavior, not an oversight.
//
// TODO (next): Consolidate schemaConversationsProvider with rawConversationsStreamProvider.
//
// ## Banned patterns
//
// The following are PROHIBITED anywhere outside the canonical providers above:
//
// ```dart
// // ❌ NEVER do this in a widget or controller
// FirebaseFirestore.instance.collection('conversations').snapshots()
// FirebaseFirestore.instance.collection('rooms').snapshots()
// FirebaseFirestore.instance.collection('follows').snapshots()
//
// // ✅ Always do this instead
// ref.watch(rawConversationsStreamProvider(userId))
// ref.watch(roomDocStreamProvider(roomId))
// ref.watch(rawFollowGraphStreamProvider(userId))
// ```
//
// ## firestoreProvider rule
//
// `firestoreProvider` is declared ONCE in:
//   `lib/core/providers/firebase_providers.dart`
//
// It must NOT be redeclared in any feature file.
// ignore_for_file: unused_import

// Canonical Firebase provider — the only declaration in the codebase.
export 'package:mixvy/core/providers/firebase_providers.dart'
    show firestoreProvider, firebaseAuthProvider;

// Canonical stream providers — re-exported for convenience.
export 'package:mixvy/features/messaging/providers/messaging_provider.dart'
    show
        rawConversationsStreamProvider,
        conversationsStreamProvider,
        requestsStreamProvider,
        conversationDocProvider;

export 'package:mixvy/features/follow/providers/follow_provider.dart'
    show rawFollowGraphStreamProvider, rawFollowerIdsStreamProvider;

export 'package:mixvy/features/room/providers/participant_providers.dart'
    show roomDocStreamProvider, participantsStreamProvider;

export 'package:mixvy/features/friends/providers/friends_providers.dart'
    show rawAllFriendshipsStreamProvider, rawAcceptedFriendshipsStreamProvider;

// ─── Runtime stream-registry validator ───────────────────────────────────────
//
// `StreamRegistryValidator.validate()` runs in debug builds only.
// It checks a table of known canonical providers against a caller-supplied
// set of currently-active provider names to detect unregistered streams.
//
// Usage (in main.dart, debug mode only):
//
//   if (kDebugMode) StreamRegistryValidator.validate(activeProviderNames);
//
// The validator never throws. It only logs warnings via developer.log.

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// The definitive allow-list of provider names that are permitted to open
/// Firestore `.snapshots()` calls directly.
///
/// Everything outside this list is either:
///   a) a derived provider (acceptable — no new stream)
///   b) a rogue direct subscriber (violation — must be fixed)
const Set<String> kCanonicalStreamProviderNames = {
  // Messaging
  'rawConversationsStreamProvider',
  'messagesStreamProvider',
  'conversationDocProvider',
  // Follow graph
  'rawFollowGraphStreamProvider',
  'rawFollowerIdsStreamProvider',
  // Room
  'roomDocStreamProvider',
  'participantsStreamProvider',
  'roomsStreamProvider',
  // Friendships
  'rawAllFriendshipsStreamProvider',
  'rawAcceptedFriendshipsStreamProvider',
  // Feed
  'userPostsStreamProvider',
  // Notifications (intentionally global — see registry table)
  'notificationsStreamProvider',
  // Verification
  'verifiedUsersProvider',
  'userVerificationProvider',
  // Schema messenger conversations (pending consolidation — see registry TODO)
  'schemaConversationsProvider',
  // Auth / presence (not Firestore, but tracked)
  'schemaAuthUserIdProvider',
};

/// Dev-only validator that compares active provider names against the
/// canonical allow-list. Zero cost in release builds.
abstract final class StreamRegistryValidator {
  /// Call this once after [ProviderScope] is mounted, passing any names you
  /// want to audit. In practice the most useful approach is to pass the
  /// provider names returned by your test harness or a reflection utility.
  ///
  /// In production (`kDebugMode == false`) this is a complete no-op.
  static void validate(Iterable<String> activeProviderNames) {
    if (!kDebugMode) return;

    final unregistered = <String>[];
    for (final name in activeProviderNames) {
      if (!kCanonicalStreamProviderNames.contains(name) &&
          (name.contains('StreamProvider') || name.contains('snapshots'))) {
        unregistered.add(name);
      }
    }

    if (unregistered.isEmpty) {
      developer.log(
        '✅ StreamRegistry: all active stream providers are registered.',
        name: 'StreamRegistry',
      );
      return;
    }

    final buffer = StringBuffer()
      ..writeln()
      ..writeln('┌── STREAM REGISTRY: UNREGISTERED STREAM PROVIDERS ──────────')
      ..writeln('│  The following providers open Firestore streams but are not')
      ..writeln(
        '│  in the canonical allow-list (kCanonicalStreamProviderNames).',
      )
      ..writeln('│  If intentional, add them to stream_registry.dart.')
      ..writeln('│  If accidental, convert to a derived provider.')
      ..writeln(
        '├─────────────────────────────────────────────────────────────',
      );
    for (final name in unregistered) {
      buffer.writeln('│  ⚠️  $name');
    }
    buffer.writeln(
      '└─────────────────────────────────────────────────────────────',
    );

    developer.log(buffer.toString(), name: 'StreamRegistry', level: 900);
  }

  /// Validate a single provider name at declaration time.
  ///
  /// Insert this into a new canonical StreamProvider's body to make
  /// architecture drift visible immediately when that provider is first used:
  ///
  /// ```dart
  /// final myNewStreamProvider = StreamProvider.autoDispose<T>((ref) {
  ///   StreamRegistryValidator.assertRegistered('myNewStreamProvider');
  ///   return ref.watch(firestoreProvider).collection('...').snapshots()...;
  /// });
  /// ```
  static void assertRegistered(String providerName) {
    if (!kDebugMode) return;
    if (!kCanonicalStreamProviderNames.contains(providerName)) {
      developer.log(
        '⚠️ StreamRegistry: "$providerName" opens a Firestore stream but is '
        'NOT in the canonical allow-list. Add it to kCanonicalStreamProviderNames '
        'in lib/core/architecture/stream_registry.dart.',
        name: 'StreamRegistry',
        level: 900,
      );
    }
  }

  /// Returns `true` if [providerName] is in the canonical allow-list.
  ///
  /// Use this for conditional logic in tests or dev tooling. In release builds
  /// always returns `true` to be a no-op.
  static bool validateStreamProviderUsage(String providerName) {
    if (!kDebugMode) return true;
    final registered = kCanonicalStreamProviderNames.contains(providerName);
    if (!registered) {
      developer.log(
        '⚠️ StreamRegistry.validateStreamProviderUsage: "$providerName" is '
        'not registered. Register it in kCanonicalStreamProviderNames or '
        'convert to a derived provider.',
        name: 'StreamRegistry',
        level: 900,
      );
    }
    return registered;
  }
}
