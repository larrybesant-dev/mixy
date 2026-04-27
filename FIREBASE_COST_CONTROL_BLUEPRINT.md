# MixVy Firebase Cost Control Blueprint

## 1. Firestore Read/Write Targets
| Action | Estimated Cost (per 1k ops) | Current Efficiency | Optimization |
| :--- | :--- | :--- | :--- |
| **Feed Fetch** | $0.06 | 1 read per post | Paginated to 15 items max. |
| **Join Room** | $0.18 | 4-6 writes | Deduplicated via Transaction. |
| **Typing** | Free* | 0 Firestore writes | Moved to Ephemeral RTDB/Subcollection. |

## 2. Listener Governance
- **Rule:** Never keep more than 2 high-frequency listeners active per screen.
- **Implementation:** `autoDispose` all Riverpod providers.
- **Risk:** The `followingFeedProvider` scales poorly (O(N) where N is following count). 
- **Fix:** If costs spike, move feed aggregation to a daily Scheduled Cloud Function.

## 3. Storage & Bandwidth
- **Images:** Enforce `memCacheHeight` (already implemented) to save local RAM, but also use Firebase Storage `cache-control` headers to reduce egress bills.
- **WebRTC Signaling:** RTDB is cheaper for rapid state changes. Use RTDB for "isTyping" and "micLevel" data; only use Firestore for persistent chat messages.

## 4. Financial "Dead Man's Switch"
1. Set **Budget Alerts** at $5, $50, and $100.
2. If $5 is hit in 24 hours during Beta, the system is leaking reads/writes.
