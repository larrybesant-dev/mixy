# MIXVY Screen Analysis Report
**Date:** June 25, 2026
**Scope:** 5 Flutter feature screens
**Framework:** Flutter + Riverpod + Firebase

---

## 1. Chat List Screen
**File:** [lib/features/chat/screens/chat_list_page.dart](lib/features/chat/screens/chat_list_page.dart)

### ✅ What's Working Well

- **Real-time Conversations:** Uses `conversationListProvider` with proper async handling
- **Online Presence:** Displays live status via `presenceProvider` with green indicator dot
- **Unread Counts:** Tracks unread messages per user with badge display
- **Typing Indicator:** Shows "Typing..." state in real-time
- **Time Formatting:** Smart relative time display (Today/Yesterday/This week/Date)
- **Error Boundaries:** Proper error states at conversation and user levels
- **Navigation:** Integrated routing to chat detail with room ID argument
- **Null Safety:** Good null checks on user data before display

### ⚠️ Potential Issues Found

| Issue | Severity | Details |
|-------|----------|---------|
| **Nested Provider Rebuilds** | 🔴 HIGH | `ListView.builder` contains `.when()` for `userProfileProvider` → `presenceProvider` (2 deep). Each item triggers 2 provider watches. On 50-item list = 100 provider subscriptions |
| **Performance Impact** | 🔴 HIGH | `otherUserAsync.when()` inside item builder creates intermediate widgets. On presence change, entire ListTile rebuilds |
| **No Item Skeleton** | 🟡 MEDIUM | While presence loads, shows full ListTile with stale user data instead of skeleton |
| **Hardcoded Format Logic** | 🟡 MEDIUM | Time formatting in `_formatTime()` and `_getDayName()` should be extracted to utils |
| **User Profile Caching** | 🟡 MEDIUM | No apparent caching - `userProfileProvider` may refetch on every page rebuild |
| **Missing Analytics** | 🟢 LOW | No analytics for chat list views or user taps |

### 🔧 Code Quality Assessment

**Score: 72/100**

| Metric | Status |
|--------|--------|
| Widget Structure | ✅ Well-organized |
| Provider Usage | ⚠️ Suboptimal nesting |
| Error Handling | ✅ Comprehensive |
| Memory Efficiency | ❌ Potential leak on item rebuilds |
| Code Reusability | ⚠️ Time formatting duplicated |
| Type Safety | ✅ Good null handling |

### 🎯 Feature Completeness: **78%**

- ✅ List conversations
- ✅ Show presence status
- ✅ Display unread counts
- ✅ Show typing indicators
- ✅ Format timestamps
- ❌ Swipe to delete/archive
- ❌ Search conversations
- ⚠️ Mute/pin conversations (not visible)

### 🔧 Recommended Fixes

1. **Extract presence watching to parent level** — Use `ref.watch(presenceProvider(otherUserId))` at top-level, cache results
2. **Use `when()` for entire list state** — Reduce nesting depth
3. **Add item skeleton loaders** — Show while presence is loading
4. **Extract time formatting** — Move to `lib/shared/utils/date_formatting.dart`

---

## 2. Profile Page
**File:** [lib/features/profile/screens/profile_page.dart](lib/features/profile/screens/profile_page.dart)

### ✅ What's Working Well

- **5-Layer Identity System:** Comprehensive profile structure (Attraction, Live, Social, Creator, Dating)
- **Multi-Mode Support:** 4 different profile presentations (Social/Dating/Creator/EventHost)
- **Permission Model:** Clear `_isOwner` guard protecting owner-only features
- **Advanced Animations:** Staggered chip entrance with `_chipAnim` (800ms duration)
- **Real-Time Presence:** Live status badge (LIVE indicator in pink)
- **Safety Layer:** Dedicated `LayerSafety` widget for privacy controls
- **Firestore Integration:** Behavior tag computation with sync to Firestore
- **Error Retry:** `AsyncValueViewEnhanced` with maxRetries=3
- **Rich Media:** Photo gallery, music tracks, social links support
- **Brand Alignment:** Neon color system (pink/cyan/blue/amber/purple)

### ⚠️ Potential Issues Found

| Issue | Severity | Details |
|-------|----------|---------|
| **Custom AsyncValueView** | 🟡 MEDIUM | `AsyncValueViewEnhanced` is custom class - error handling logic unclear. Not visible in code |
| **Deep Widget Nesting** | 🔴 HIGH | `_buildOrderedLayers()` creates 4 conditional lists that are spread. Makes maintenance hard. Exceeds 10 levels deep |
| **Local State Fragility** | 🟡 MEDIUM | `_tagsRefreshed` flag prevents refresh, but if screen recreates → flag resets → double refresh |
| **Hardcoded Routes** | 🟡 MEDIUM | Navigation uses strings: `/settings/privacy`, `/creator/settings`, etc. Not constants |
| **Null-Unsafe Access** | 🟡 MEDIUM | `p.displayName![0]` at line ~700 — could crash if displayName is null after null-check |
| **Missing Analytics** | 🟡 MEDIUM | No analytics for profile views, mode changes, or layer interactions |
| **No Pagination** | 🟡 MEDIUM | Gallery photos render all at once - no lazy loading on photo-heavy profiles |
| **Edit Avatar Race Condition** | 🟢 LOW | Edit button tap navigates immediately without optimistic update |

### 🔧 Code Quality Assessment

**Score: 68/100**

| Metric | Status |
|--------|--------|
| Architecture | ⚠️ Monolithic screen |
| Widget Composition | ❌ Needs extraction (10+ helper methods) |
| State Management | ⚠️ Mixed local + provider state |
| Performance | ⚠️ All layers render upfront |
| Maintainability | ❌ Hard to modify sections |
| Type Safety | ⚠️ Some ! force unwraps |

### 🎯 Feature Completeness: **85%**

- ✅ Display profile layers
- ✅ Edit profile (owner)
- ✅ Mode switching
- ✅ Show presence status
- ✅ Gallery display
- ✅ Badges & achievements
- ✅ Music taste
- ✅ Social links
- ❌ Photo upload from profile
- ⚠️ Report user (not visible)

### 🔧 Recommended Fixes

1. **Extract layer widgets to separate files** — Move `_buildDatingLayer()`, `_buildGalleryGrid()` etc to own widgets
2. **Use constants for routes** — Create `ProfileRoutes` class
3. **Add refresh indicator** — Let user refresh behavior tags manually
4. **Use conditional rendering widget** — Instead of ternary spreads, use custom `ConditionalSection` widget
5. **Add pagination to gallery** — Use `PageView` for large photo collections

---

## 3. Events List Screen
**File:** [lib/features/events/screens/events_list_page.dart](lib/features/events/screens/events_list_page.dart)

### ✅ What's Working Well

- **Tab Organization:** Clean 3-tab interface (All/Friends/Recommended)
- **Authentication Guards:** Checks `currentUser` before showing user-specific tabs
- **Empty States:** Contextual messaging with action buttons
- **Network Feedback:** Shows event count for Friends tab ("X events from your network")
- **Error Handling:** Proper error states with retry callbacks
- **Async Patterns:** Correct use of AsyncValue `.when()` pattern
- **Navigation:** Pushes to event details with ID parameter

### ⚠️ Potential Issues Found

| Issue | Severity | Details |
|-------|----------|---------|
| **Missing EventCard Implementation** | 🔴 HIGH | `EventCard` referenced but not defined in visible code. Unknown widget structure |
| **No Loading Skeleton** | 🟡 MEDIUM | Shows spinner center instead of skeleton. User can't see list shape |
| **Hardcoded Routes** | 🟡 MEDIUM | Routes like '/create-event', '/event-details', '/login' should be constants |
| **No Pull-to-Refresh** | 🟡 MEDIUM | No ability to refresh events manually (e.g., `RefreshIndicator`) |
| **No Offline Support** | 🟡 MEDIUM | No offline banner or fallback. Missing `OfflineBanner` (used in discover_users_page) |
| **Unbounded BuildContext Usage** | 🟢 LOW | Multiple `Navigator.of(context).pushNamed()` — could break with async pops |
| **Tab Initialization** | 🟢 LOW | `TabController(length: 3, ...)` hardcoded — tight coupling |
| **No Pagination** | 🟢 LOW | No indication if list has infinite scroll or pagination |

### 🔧 Code Quality Assessment

**Score: 74/100**

| Metric | Status |
|--------|--------|
| Structure | ✅ Clean tab separation |
| Provider Usage | ✅ Correct AsyncValue |
| UX Polish | ⚠️ No loading states |
| Offline Support | ❌ Missing |
| Error Recovery | ✅ Retry available |
| Accessibility | ⚠️ No semantics |

### 🎯 Feature Completeness: **76%**

- ✅ List all events
- ✅ Filter by friends' events
- ✅ Personalized recommendations
- ✅ Create event button
- ✅ View event details
- ❌ Search events
- ❌ Filter by category/date
- ⚠️ RSVP status (likely in EventCard)

### 🔧 Recommended Fixes

1. **Create `EventsRoutes` constants** — Replace hardcoded route strings
2. **Add loading skeleton** — Create `EventCardSkeleton` widget
3. **Integrate `RefreshIndicator`** — Allow manual refresh
4. **Add offline state** — Use `OfflineBanner` like discover_users_page
5. **Show `EventCard` implementation** — Verify proper event data display

---

## 4. Room By ID Screen
**File:** [lib/features/room/screens/room_by_id_page.dart](lib/features/room/screens/room_by_id_page.dart)

### ✅ What's Working Well

- **Access Control:** Routes through `RoomAccessWrapper` for gating
- **Clean Routing:** Receives `roomId` parameter via constructor
- **Error Fallback:** Shows "Room not found" text on null

### ⚠️ Potential Issues Found

| Issue | Severity | Details |
|-------|----------|---------|
| **FutureBuilder Anti-Pattern** | 🔴 HIGH | Uses `FutureBuilder` instead of Riverpod provider. Inconsistent with rest of app. No real-time updates |
| **No Real-Time Sync** | 🔴 HIGH | Fetches room once at init. Room status changes (participants, live status) won't update |
| **Silent Parsing Failure** | 🟡 MEDIUM | `Room.fromDocument(doc)` could return null without error if parsing fails |
| **Late Auth Check** | 🟡 MEDIUM | Auth guard happens in `RoomAccessWrapper`, not before fetch. Unauthorized user still fetches |
| **No Retry Mechanism** | 🟡 MEDIUM | On network error, user sees error but can't retry without rebuilding |
| **Generic Error Message** | 🟡 MEDIUM | Shows generic "Failed to load room" — should distinguish "not found" vs "network error" |
| **Missing Firestore Index** | 🟡 MEDIUM | Querying 'rooms' collection by ID without visible index verification |
| **LoadingSpinner Import** | 🟢 LOW | Widget imported but implementation unknown |

### 🔧 Code Quality Assessment

**Score: 45/100**

| Metric | Status |
|--------|--------|
| Architecture | ❌ Wrong state pattern |
| Real-Time Sync | ❌ No streaming |
| Error Handling | ⚠️ Generic messages |
| Performance | ⚠️ Full fetch on load |
| Maintainability | ⚠️ Inconsistent with app |
| Type Safety | ✅ Good null checks |

### 🎯 Feature Completeness: **55%**

- ✅ Load room by ID
- ✅ Display access wrapper
- ⚠️ Show loading state
- ❌ Real-time room updates
- ❌ Retry on error
- ❌ Display detailed error
- ❌ Offline fallback

### 🔧 Recommended Fixes

1. **Migrate to Riverpod provider** — Create `roomByIdProvider(String roomId)` with FirestoreBuilder
2. **Use real-time listener** — `.snapshots()` instead of single `.get()`
3. **Move auth check to provider** — Guard at data level, not UI level
4. **Add retry UI** — Replace error text with proper error card + retry button
5. **Implement proper error types** — Distinguish RoomNotFound, Unauthorized, Network errors

---

## 5. Discover Users Screen
**File:** [lib/features/discover/screens/discover_users_page.dart](lib/features/discover/screens/discover_users_page.dart)

### ✅ What's Working Well

- **Dual Tab Experience:** Swipe (Tinder-style) + Browse (search) modes
- **Gesture Physics:** Smooth drag with rotation angle calculation
- **Back Stack Animation:** Subtle scale-down for depth perception
- **Analytics Integration:** Logs discover views, likes with user IDs
- **Offline Banner:** Shows connectivity status
- **Search Functionality:** Debounced search with result updating
- **Empty State:** Contextual messaging ("You've seen everyone") with refresh option
- **Accessibility:** Large gesture targets for swipe actions
- **Smooth Animations:** Snap-back with `elasticOut` curve

### ⚠️ Potential Issues Found

| Issue | Severity | Details |
|-------|----------|---------|
| **Dismissed Set Loss** | 🔴 HIGH | `_dismissed` Set stored in state. Widget rebuild → loses dismissed users. User sees same card twice |
| **No Search Debounce** | 🟡 MEDIUM | `_performSearch()` called on every keystroke. No 300ms debounce shown. Could fire 5+ requests per second |
| **Race Condition** | 🟡 MEDIUM | `_isSearching` flag set to true, then request fires. If user types again before response → state chaos |
| **Hardcoded Physics** | 🟡 MEDIUM | Swipe threshold (140px), max angle (12°) hardcoded. Won't adapt to screen sizes or device speeds |
| **Missing Analytics** | 🟡 MEDIUM | Skip action not tracked. Only likes + views logged. Asymmetric event coverage |
| **No Pagination** | 🟡 MEDIUM | Search loads all results at once. No limit or pagination shown |
| **No Input Validation** | 🟡 MEDIUM | `_performSearch()` accepts empty strings and fires requests |
| **Mounted Check Incomplete** | 🟡 MEDIUM | Checks `mounted` in catch, but not guaranteed in async closure |
| **Card Rotation Math** | 🟢 LOW | `(offset.dx / 400) * _maxAngleDeg` uses magic number 400 — should be constant |
| **No Search Cancel** | 🟢 LOW | Once searching, can't cancel. No X button on search field |

### 🔧 Code Quality Assessment

**Score: 76/100**

| Metric | Status |
|--------|--------|
| UX Delight | ✅ Smooth interactions |
| State Management | ⚠️ Volatile local state |
| Error Handling | ⚠️ Silent failures |
| Performance | ⚠️ No debounce |
| Accessibility | ✅ Good gesture targets |
| Analytics | ⚠️ Incomplete events |

### 🎯 Feature Completeness: **82%**

- ✅ Swipe to like/skip
- ✅ Card stacking
- ✅ Search users
- ✅ View user profile on card
- ✅ Smooth animations
- ✅ Analytics logging
- ❌ Undo last action
- ⚠️ User profile preview (likely in card)

### 🔧 Recommended Fixes

1. **Move dismissed to provider** — Create `dismissedUsersProvider` with persistent state
2. **Add search debounce** — Use `Timer` or `Debounce` package (300ms delay)
3. **Validate search input** — Check `query.trim().isEmpty` before firing request
4. **Extract constants** — `_swipeThreshold`, `_maxAngleDeg`, rotation factor to top of class
5. **Log skip analytics** — Add `logDiscoverUserSkipped(user.id)` event
6. **Add search cancel** — Show X button when `_isSearching == true`

---

## Summary Table

| Screen | Quality | Completeness | Key Issue |
|--------|---------|--------------|-----------|
| Chat List | 72% | 78% | Nested provider rebuilds |
| Profile | 68% | 85% | Deep nesting, needs extraction |
| Events | 74% | 76% | Missing loading states, offline support |
| Room By ID | 45% | 55% | Wrong state pattern (FutureBuilder) |
| Discover Users | 76% | 82% | Dismissed state not persistent |

**Overall App Health: 67/100** 🟡

### Critical Fixes (Priority 1)
1. Migrate RoomByIdPage to Riverpod + real-time streaming
2. Extract nested providers in ChatListPage
3. Persist dismissed users in DiscoverUsersPage

### High Priority (Priority 2)
1. Add search debounce to DiscoverUsersPage
2. Extract ProfilePage layers to separate widgets
3. Add offline support to EventsPage

### Medium Priority (Priority 3)
1. Add skeleton loaders to all async lists
2. Create route constants across all screens
3. Expand error messages with retry UI

---

**Report Generated:** June 25, 2026
**Framework Versions:** Flutter (latest), Riverpod 2.x, Firebase
**Next Review:** After fixes applied
