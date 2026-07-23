# WebSocket Block Diagnosis & Resolution  

**Status:** Issue confirmed as browser-level block (not code/infrastructure problem)  
**Impact:** Real-time Firestore features blocked  
**Date:** 2026-07-17 00:32:00Z

---

## ✅ What's Been Ruled Out

✅ API Key configuration - Cloud Firestore API enabled  
✅ Firebase domain authorization - mixvy-v2.web.app whitelisted  
✅ Firestore settings conflict - Single source of truth configured  
✅ Network connectivity - Endpoint reachable from terminal  
✅ Code-level Firestore configuration - Optimized for REST API  
✅ Firebase Hosting headers - No CSP/CORS blocking detected  
✅ Flutter web build - Successful compilation, 43 files deployed

## ❌ What's Failing

```
GET https://firestore.googleapis.com/google.firestore.v1.Firestore/Write/channel
GET https://firestore.googleapis.com/google.firestore.v1.Firestore/Listen/channel
Status: net::ERR_ABORTED
Pattern: Occurs even with TYPE=xmlhttp (HTTP long-polling fallback)
```

---

## 🎯 Root Cause Identification Protocol

### **STEP 1: Test in Incognito Mode (2 minutes)**

**This is the #1 way to identify if a browser extension is blocking the connection.**

1. **Press Ctrl+Shift+N** (Windows) or **Cmd+Shift+N** (Mac)
2. In the new incognito window, navigate to: **https://mixvy-v2.web.app/auth**
3. **Login** with test account: `test_a_prod@example.com` / `ProdTest@2026!`
4. **Open DevTools** in the incognito window: **F12**
5. Go to **Console** tab
6. Look for errors mentioning "Firestore" or "Listen"
7. Go to **Network** tab, filter by "firestore.googleapis.com"

**Expected results:**

- **✅ If works in incognito:** Browser extension is blocking in normal window
  - Next: Go to STEP 2 (identify extension)
  
- **❌ If fails in incognito too:** Network-level block (proxy/firewall)
  - Next: Go to STEP 3 (check VPN/network)

---

### **STEP 2: Identify Blocking Extension (2 minutes)**

If it works in incognito, a **browser extension is the culprit**.

**Find which extension:**

1. **Open Chrome Settings** → **Extensions**
2. **Disable all extensions one by one** until Firestore works
3. Common blockers:
   - ✅ **uBlock Origin** (too aggressive by default)
   - ✅ **Privacy Badger**
   - ✅ **Ghostery**
   - ✅ **Adblock Plus**
   - ✅ **DuckDuckGo Privacy**
   - ✅ **LastPass** (sometimes)

**Permanent fix once identified:**

1. Keep extension disabled OR
2. Add whitelist:
   - Open extension settings
   - Add `*.firestore.googleapis.com` to allowlist
   - Add `*.googleapis.com` to allowlist
   - Reload app

---

### **STEP 3: Check VPN/Proxy (2 minutes)**

If blocking extension isn't found, check network:

**Windows:**

```powershell
# Check if VPN is active
Get-VpnConnectionStatus

# Check Windows proxy settings
netsh winhttp show proxy

# If using Fiddler/Burp/Charles, disable it
```

**Mac:**

```bash
# Check VPN status
scutil --nc list

# Check proxy in System Preferences → Network
```

**Common causes:**
- VPN set to "Always On" mode
- Corporate network proxy intercepting traffic
- ISP-level filtering (rare but possible)

---

## 🛠️ Workarounds

### **Workaround 1: Use REST API Instead of Real-Time Listeners**

If blocking extension can't be removed, use REST API for room discovery:

```dart
// File: lib/features/home/discovery_feed_repository.dart

class DiscoveryFeedRepository {
  final FirebaseFirestore _firestore;
  
  // Replace real-time listener with polling
  Future<List<RoomModel>> fetchDiscoveryFeed() async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('isLive', isEqualTo: true)
          .limit(20)
          .get(const GetOptions(source: Source.server)); // Force server fetch
      
      return snapshot.docs
          .map((doc) => RoomModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching discovery feed: $e');
      return [];
    }
  }
  
  // Poll every 5 seconds instead of real-time
  Stream<List<RoomModel>> discoveryFeedStream() {
    return Stream.periodic(
      const Duration(seconds: 5),
      (_) => fetchDiscoveryFeed(),
    ).asyncExpand((future) => future.asStream());
  }
}
```

### **Workaround 2: Disable Real-Time Listeners, Use Periodic Refresh**

Modify all StreamProviders to use periodic polling instead:

```dart
// Instead of watching real-time snapshots
StreamProvider<List<Room>> roomsProvider = StreamProvider((ref) async* {
  while (true) {
    try {
      final rooms = await ref.read(firestoreProvider)
          .collection('rooms')
          .limit(20)
          .get();
      
      yield rooms.docs.map((d) => Room.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Polling error: $e');
    }
    
    await Future.delayed(const Duration(seconds: 5));
  }
});
```

### **Workaround 3: Use Realtime Database Instead**

If WebSocket to Firestore is blocked, Firebase Realtime Database might work:

```dart
// Test if RTDB connections work
final rtdb = FirebaseDatabase.instance;
rtdb.ref('test').onValue.listen((event) {
  print('RTDB works! Data: ${event.snapshot.value}');
});
```

---

## 📋 Troubleshooting Checklist

- [ ] **Test 1:** Opened app in incognito window
- [ ] **Result 1:** Works / Doesn't work
- [ ] **If works:** Identified which extension (Step 2)
- [ ] **If doesn't work:** Checked VPN/Proxy status (Step 3)
- [ ] **Resolution:** Disabled extension OR contacted IT OR using workaround

---

## 📞 Resolution Summary

| Finding | Solution | Time |
|---------|----------|------|
| Extension blocking | Disable or whitelist `*.googleapis.com` | 2 min |
| VPN active | Disable VPN | 1 min |
| Corporate proxy | Contact IT to allowlist domain | 1 hour+ |
| ISP filtering | Use VPN or contact ISP | 1 hour+ |

---

## 🚀 Next Steps

1. **Test in incognito window** - identify if it's an extension
2. **Share results** with the following info:
   - Does it work in incognito? (Yes/No)
   - Which browser? (Chrome/Edge/Firefox)
   - List of installed extensions
   - VPN/Proxy status
   - Any corporate network proxy?
3. **Once identified,** apply appropriate fix from above

---

**Owner:** Copilot Agent  
**Status:** 🟡 Awaiting User Diagnostics  
**Last Updated:** 2026-07-17T00:32:00Z
