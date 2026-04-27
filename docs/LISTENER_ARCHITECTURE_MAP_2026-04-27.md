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
- Debug overlay production gate verified:
	- `AppDebugOverlay` mounted only under `kDebugMode` in `lib/app/app.dart`.

## Current Listener Hotspots

### Messaging
- `conversationsStreamProvider` (`conversations` collection listener)
- `requestsStreamProvider` (`conversations` pending listener)
- `messagestreamProvider` (`messages` subcollection listener)
- `messageReactionsProvider` (reactions stream)
- Typing/read-receipt stream providers
- File: `lib/features/messaging/providers/messaging_provider.dart`

Risk:
- Multiple concurrent realtime subscriptions when inbox + chat + desktop shell elements are mounted.

### Feed/Social
- `roomsStreamProvider` (shared live rooms realtime stream)
- `currentUserActivitiesProvider` (realtime social activity stream)
- `postsFeedProvider` and `userPostsStreamProvider` (realtime post streams)
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

1. Messaging stream consolidation (high)
- Build a single base conversation stream and derive inbox/request views from it where possible.
- Ensure only active chat pane watches message/reaction/typing streams.

2. Feed stream scope tightening (medium)
- Keep rooms realtime on active social surfaces.
- Convert passive or vanity realtime streams to one-shot fetch when realtime adds little UX value.

3. Friends overlap reduction (medium)
- Audit whether `friendsProvider`, `friendRosterProvider`, and `friendsListProvider` can share base data.
- Keep presence realtime only where visible.

## Validation Performed
- `flutter analyze` on changed social/provider/app shell files: clean.
- Router redirect smoke test: pass.

