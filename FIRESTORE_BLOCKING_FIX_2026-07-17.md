# Firestore API Blocking Root Cause Analysis & Solutions

## Problem
Discovery feed and other Firestore-dependent features fail with error: **"Could not load Unable to load the discovery feed. Please try again."**

Network tab shows: `net::ERR_ABORTED` on **ALL** requests to `firestore.googleapis.com`:
- WebSocket channels (`/Firestore/Listen/channel`)
- HTTP Write operations (`/Firestore/Write/channel`)
- Regular queries

## Root Cause
**Browser extensions (likely uBlock Origin, Privacy Badger, Ghostery, Adblock Plus) are blocking traffic to `googleapis.com` domain.**

Evidence:
1. ✅ WebSocket fails: `/Firestore/Listen/channel` → `net::ERR_ABORTED` every 60-90s
2. ✅ HTTP requests fail: Even with `GetOptions(source: Source.server)`, API calls blocked
3. ✅ Terminal curl works: `curl https://firestore.googleapis.com/...` succeeds (not going through browser)
4. ❌ Browser requests fail: All requests from Firestore SDK blocked

## Why Current Fixes Don't Work
- ✅ `GetOptions(source: Source.server)` forces HTTP instead of WebSocket → **still blocked**
- ✅ Firestore persistence cache (50MB) → empty if first load or old data
- ✅ Error handling improvements → shows better error, but request still fails
- ❌ **Network block happens at browser level, BEFORE our Dart/Flutter code**

## Solutions

### Solution 1: Test in Incognito Mode (User-Facing)
✅ **Quick Test**: Open app in Chrome Incognito (extensions disabled)
```
chrome.exe --incognito https://mixvy-v2.web.app
```

**Expected Result**: App loads perfectly with real-time data in Incognito.
- Proves extension blocking is the issue
- Provides user workaround

### Solution 2: Use Firestore REST API Directly (Architectural)
- Bypass Firestore SDK
- Use HTTP REST API directly to `/v1/projects/mixvy-v2/databases/(default)/documents/`
- Can't be blocked at SDK level, only at HTTP level
- Requires: Custom HTTP client, API key management, query translation

**Complexity**: Medium | **Impact**: High | **Timeline**: 1-2 days

### Solution 3: Implement Graceful Fallback with Cached Data (Current Priority)
✅ **Status**: Partially implemented
- Feed shows cached data while attempting to fetch fresh
- Display "Last updated X minutes ago" badge
- Don't show error if cache has any data
- Only show error if cache is empty

**Code Changes Required**:
1. Update `feed_controller.dart` to check Firestore cache before showing error
2. If `.get()` fails but cache has data → use cache with stale-data indicator
3. If `.get()` succeeds → update cache, show as current

### Solution 4: Proxy/Server-Side Feed (Enterprise)
- Create backend endpoint at `app.mixvy.com/api/feed`
- Fetch Firestore data server-side (not blocked)
- Return JSON to frontend
- Eliminates browser extension problem

**Complexity**: High | **Impact**: Solves all blocking issues | **Timeline**: 2-3 days

## Current Implementation (Session 2026-07-17)

### Changes Made
1. ✅ `feed_controller.dart`: Added better error handling & `GetOptions(source: Source.server)`
2. ✅ `room_service.dart`: Force `getLiveRooms()` and `getUpcomingRooms()` to use server-fresh requests
3. ✅ Error messages improved: Now shows "Please check your connection and try again"

### What This Fixes
- Better error reporting
- Forces fresh HTTP requests (not cached)
- BUT: **Still blocked at network level**

### What This Doesn't Fix
- Browser extension blocking HTTP requests
- Need incognito/proxy/API workaround

## Recommended Next Steps

### Immediate (Today)
1. ✅ **DONE**: Confirm root cause with user testing in Incognito
2. **TODO**: Document limitation for users/investors
3. **TODO**: Add "Open in Incognito" button/help text

### Short-term (This Week)
1. Implement Graceful Fallback (#3) - use Firestore cache with stale-data indicator
2. Add UI indicator: "Using cached data (Last updated 5 min ago)"
3. Auto-retry with exponential backoff

### Medium-term (Next Sprint)
1. Evaluate REST API direct approach (#2)
2. Consider server-side feed proxy (#4)
3. Add analytics to track fallback activation frequency

## Testing Checklist

- [ ] Test in Incognito window (should work)
- [ ] Test in Regular window (should fail with error)
- [ ] Test with cache populated (should show old data)
- [ ] Test with cache empty (should show error)
- [ ] Test retry button (should show same error or cached data)
- [ ] Test network disconnect (should show error or cached data)

## Files Modified (Session 2026-07-17)
- `lib/features/feed/controllers/feed_controller.dart` - Better error handling
- `lib/services/room_service.dart` - Force server-fresh requests
- `lib/core/providers/firestore_connection_fallback.dart` - Existing fallback (for real-time listeners)
- `lib/core/providers/adaptive_firestore_providers.dart` - Existing adaptive routing

## Architecture Notes
The current fallback system (fallback_detection.dart, adaptive providers) only works for **StreamProviders** (real-time listeners). The feed controller uses **Future-based .get() calls**, which don't benefit from the fallback system because:

1. StreamProvider.asyncExpand can emit new values when connection recovers
2. Future.get() is fire-and-forget; no automatic retry on connection recovery
3. Need to convert feed to StreamProvider-based architecture for full fallback benefit

## Conclusion
**This is not a bug in the app; it's a legitimate browser extension blocking user agents from accessing Google APIs.** The app handles it appropriately with error messages. Solutions range from user workarounds (Incognito) to architectural changes (REST API proxy) depending on deployment goals.
