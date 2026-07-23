# Listener Architecture Map (2026-04-27)

## Scope
- Web runtime listener behavior for startup path `/home` and major social/messaging surfaces.
- Focus on Firestore `snapshots()` and long-lived `StreamProvider` subscriptions.

## Startup Path
- Route `/home` resolves to `AppShell` in `lib/router/app_router.dart`.
- `AppShell` previously used `IndexedStack` and kept all tabs mounted.
- `AppShell` now renders active tab only in `lib/shared/widgets/app_shell.dart`.

## Optimization Changes Applied
- Social live-room stream de-dup:
	- `followingLiveRoomsProvider` now derives from shared `roomsStreamProvider` + follows IDs.
	- `newLiveRoomsProvider` now derives from shared `roomsStreamProvider`.
	- File: `lib/features/social/providers/social_providers.dart`.
- Tab lifecycle hardening:
	- `AppShell` switched from `IndexedStack` to active-tab-only rendering.
	- File: `lib/shared/widgets/app_shell.dart`.
- Messaging consolidation (slice 2):
	- Added `rawConversationsStreamProvider` as the single Firestore conversation listener.
	- `conversationsStreamProvider` now derives active conversations from raw stream.
	- `requestsStreamProvider` now derives pending requests from the same raw stream.
	- Removed separate pending-requests Firestore subscription.
	- File: `lib/features/messaging/providers/messaging_provider.dart`.
- Feed cost optimization (slice 3):
	- `currentUserActivitiesProvider` moved from realtime stream to one-shot fetch provider.
	- Added `SocialActivityService.getUserActivities(...)` for non-realtime dashboard/feed use.
	- Removed unused legacy `following_feed_provider.dart` to prevent accidental realtime reintroduction.
	- Files: `lib/features/feed/providers/feed_providers.dart`, `lib/services/social_activity_service.dart`.
- Debug overlay production gate verified:
	- `AppDebugOverlay` mounted only under `kDebugMode` in `lib/app/app.dart`.

## Current Listener Hotspots

### Messaging
- `rawConversationsStreamProvider` (`conversations` collection listener)
- `conversationsStreamProvider` (derived active subset, no extra listener)
- `requestsStreamProvider` (derived pending subset, no extra listener)
- `messagestreamProvider` (`messages` subcollection listener)
- `messageReactionsProvider` (reactions stream)
- Typing/read-receipt stream providers
- File: `lib/features/messaging/providers/messaging_provider.dart`

Risk:
- Multiple concurrent realtime subscriptions when inbox + chat + desktop shell elements are mounted.

### Feed/Social
- `roomsStreamProvider` (shared live rooms realtime stream)
- `userPostsStreamProvider` (profile post stream)
- `currentUserActivitiesProvider` is now one-shot (no persistent listener)
- File: `lib/features/feed/providers/feed_providers.dart`

Risk:
- Realtime streams are justified for active surfaces, but still need strict visibility scoping.

### Friends
- `friendsProvider`
- `friendRosterProvider`
- `friendsListProvider`
- `incomingFriendRequestsProvider`
- `pendingOutgoingFriendRequestIdsProvider`
- File: `lib/features/friends/providers/friends_providers.dart`

Risk:
- Potential overlap/redundancy across friendship + roster + presence streams.

## Priority Next Slices

1. Messaging stream consolidation (follow-up)
- Ensure only active chat pane watches message/reaction/typing streams.
- Add light typing/debounce safeguards for high-churn rooms.

2. Feed stream scope tightening (follow-up)
- Keep rooms realtime on active social surfaces.
- Audit and remove any remaining unused realtime providers.

3. Friends overlap reduction (medium)
- Audit whether `friendsProvider`, `friendRosterProvider`, and `friendsListProvider` can share base data.
- Keep presence realtime only where visible.

## Validation Performed
- `flutter analyze` on changed social/provider/app shell files: clean.
- Router redirect smoke test: pass.
- `flutter analyze` on messaging provider + dependent messaging/shell files: clean.
- `flutter test test/messages_screen_test.dart`: pass.
- `flutter analyze` on feed providers + discovery/dashboard social activity changes: clean.
- `flutter test test/home_feed_snapshot_test.dart test/discovery_feed_screen_test.dart`: pass.

