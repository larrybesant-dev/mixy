/// # MixVy Stream Registry
///
/// **ONE RULE: ONE FEATURE = ONE STREAM SOURCE.**
///
/// Every live Firestore stream in the app must be listed here.
/// Any provider that opens a `.snapshots()` call directly MUST delegate
/// through the canonical provider listed in this registry.
///
/// ## How to use
///
/// 1. Before adding a new StreamProvider:
///    - Check this registry. If a stream for this domain already exists, use it.
///    - Never open a second `.snapshots()` for the same collection + filter.
///
/// 2. After adding a new canonical stream:
///    - Add it to the registry below.
///    - Add a static assertion in [StreamRegistryAssertions] so the analyzer
///      catches future duplicates at test time.
///
/// ## Enforcement
///
/// Run `flutter test lib/core/architecture/stream_registry_test.dart` to
/// verify no duplicate streams are active in the provider graph.
///
/// ## Registry (alphabetical by domain)
///
/// | Domain           | Canonical provider                        | File                                              |
/// |------------------|-------------------------------------------|---------------------------------------------------|
/// | Conversations    | rawConversationsStreamProvider            | features/messaging/providers/messaging_provider.dart |
/// | Conversations    | conversationsStreamProvider (derived)     | features/messaging/providers/messaging_provider.dart |
/// | Conversations    | requestsStreamProvider (derived)          | features/messaging/providers/messaging_provider.dart |
/// | Conversation doc | conversationDocProvider                   | features/messaging/providers/messaging_provider.dart |
/// | Messages         | messagesStreamProvider                    | features/messaging/providers/messaging_provider.dart |
/// | Follow graph     | rawFollowGraphStreamProvider              | features/follow/providers/follow_provider.dart       |
/// | Follower IDs     | rawFollowerIdsStreamProvider              | features/follow/providers/follow_provider.dart       |
/// | Room doc         | roomDocStreamProvider                     | features/room/providers/participant_providers.dart   |
/// | Participants     | participantsStreamProvider                | features/room/providers/participant_providers.dart   |
/// | Live rooms list  | roomsStreamProvider                       | features/feed/providers/feed_providers.dart          |
/// | Presence         | presenceStreamProvider (RTDB)             | services/presence_repository.dart                   |
/// | Typing           | typingStreamProvider                      | features/feed/providers/typing_providers.dart        |
/// | Reactions        | reactionsStreamProvider                   | features/feed/providers/reaction_providers.dart      |
///
/// ## Banned patterns
///
/// The following are PROHIBITED anywhere outside the canonical providers above:
///
/// ```dart
/// // ❌ NEVER do this in a widget or controller
/// FirebaseFirestore.instance.collection('conversations').snapshots()
/// FirebaseFirestore.instance.collection('rooms').snapshots()
/// FirebaseFirestore.instance.collection('follows').snapshots()
///
/// // ✅ Always do this instead
/// ref.watch(rawConversationsStreamProvider(userId))
/// ref.watch(roomDocStreamProvider(roomId))
/// ref.watch(rawFollowGraphStreamProvider(userId))
/// ```
///
/// ## firestoreProvider rule
///
/// `firestoreProvider` is declared ONCE in:
///   `lib/core/providers/firebase_providers.dart`
///
/// It must NOT be redeclared in any feature file.
/// All features must import it via:
///   `import 'package:mixvy/core/providers/firebase_providers.dart';`

// ignore_for_file: unused_import

library stream_registry;

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
