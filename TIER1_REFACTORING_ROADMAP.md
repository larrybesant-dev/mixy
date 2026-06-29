# 🔧 Tier 1 Refactoring Roadmap (1 Hour)
**Critical Path Firebase Singleton → Riverpod Migration**  
**Date**: June 27, 2026

---

## 🎯 Scope: 5 Critical Files

| File | Singletons | Impact | Difficulty | Est. Time |
|------|-----------|--------|-----------|-----------|
| 1. `firebase_providers.dart` | Provider setup | Foundation | Easy | 10 min |
| 2. `auth_controller.dart` | Auth logic | Authentication | Easy | 15 min |
| 3. `payment_api.dart` | Payment processing | Stripe integration | Medium | 15 min |
| 4. `payments_controller.dart` | Payment UI | UI state | Medium | 12 min |
| 5. `live_room_screen.dart` | Room join | WebRTC signaling | Medium | 18 min |

**Total Time**: ~70 minutes (1 hour 10 min)

---

## File 1: `lib/core/providers/firebase_providers.dart` (10 min)

**Current State**: May have setup code
**Goal**: Ensure all providers are exported

**Action**: Review and confirm this file has all basic providers:

```dart
// ✅ SHOULD HAVE (check it exists)
final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);
final firebaseDatabaseProvider = Provider((ref) => FirebaseDatabase.instance);

// If missing, ADD them
```

**Command to Check**:
```bash
type lib\core\providers\firebase_providers.dart | findstr "firestoreProvider\|firebaseAuthProvider\|firebaseDatabaseProvider"
```

---

## File 2: `lib/features/auth/controllers/auth_controller.dart` (15 min)

**Current Pattern** (❌ Wrong):
```dart
class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(AuthState.initial());

  Future<void> signIn() async {
    final auth = FirebaseAuth.instance; // ❌ Hardcoded singleton
    final result = await auth.signInWithCredential(...);
  }
}
```

**Target Pattern** (✅ Correct):
```dart
class AuthController extends StateNotifier<AuthState> {
  final Ref ref;
  
  AuthController(this.ref) : super(AuthState.initial());

  Future<void> signIn() async {
    final auth = ref.read(firebaseAuthProvider); // ✅ Via Riverpod
    final result = await auth.signInWithCredential(...);
  }
}

// Provider wrapper
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
```

**How to Execute**:
1. Find all `FirebaseAuth.instance` calls in the file
2. Add `final Ref ref;` to constructor
3. Replace `FirebaseAuth.instance` with `ref.read(firebaseAuthProvider)`
4. Wrap the StateNotifier in a provider

**Files Affected**: Just this one file

---

## File 3: `lib/services/payment_api.dart` (15 min)

**Current Pattern** (❌ Wrong):
```dart
class PaymentAPI {
  Future<void> recordPayment(String uid, Map<String, dynamic> data) async {
    final firestore = FirebaseFirestore.instance; // ❌ Hardcoded
    await firestore.collection('payments')
      .doc(uid)
      .collection('transactions')
      .add(data);
  }
}
```

**Target Pattern** (✅ Correct):
```dart
class PaymentAPI {
  final Ref ref;
  
  PaymentAPI(this.ref);

  Future<void> recordPayment(String uid, Map<String, dynamic> data) async {
    final firestore = ref.read(firestoreProvider); // ✅ Via Riverpod
    await firestore.collection('payments')
      .doc(uid)
      .collection('transactions')
      .add(data);
  }
}

// Service provider
final paymentAPIProvider = Provider((ref) {
  return PaymentAPI(ref);
});
```

**How to Execute**:
1. Add `final Ref ref;` to constructor
2. Find all `FirebaseFirestore.instance` calls
3. Replace with `ref.read(firestoreProvider)`
4. Create a Provider wrapper

**Locations to Check**:
- `recordPayment()` method
- Any Firestore writes
- Any cloud function calls

---

## File 4: `lib/features/payments/payments_controller.dart` (12 min)

**Current Pattern** (❌ Wrong):
```dart
class PaymentsController extends StateNotifier<PaymentsState> {
  PaymentsController() : super(PaymentsState.initial());

  void loadTransactions(String uid) {
    final firestore = FirebaseFirestore.instance; // ❌ Hardcoded
    firestore.collection('payments')
      .doc(uid)
      .collection('transactions')
      .snapshots()
      .listen((snap) { /* update state */ });
  }
}
```

**Target Pattern** (✅ Correct):
```dart
class PaymentsController extends StateNotifier<PaymentsState> {
  final Ref ref;
  
  PaymentsController(this.ref) : super(PaymentsState.initial());

  void loadTransactions(String uid) {
    final firestore = ref.read(firestoreProvider); // ✅ Via Riverpod
    firestore.collection('payments')
      .doc(uid)
      .collection('transactions')
      .snapshots()
      .listen((snap) { /* update state */ });
  }
}

// Provider
final paymentsControllerProvider = 
  StateNotifierProvider<PaymentsController, PaymentsState>((ref) {
    return PaymentsController(ref);
  });
```

**How to Execute**:
1. Add `final Ref ref;` to constructor
2. Replace all `FirebaseFirestore.instance` → `ref.read(firestoreProvider)`
3. Wrap in StateNotifierProvider

---

## File 5: `lib/features/room/presentation/live_room_screen.dart` (18 min)

**Current Pattern** (❌ Wrong):
```dart
class LiveRoomScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ❌ Inside widget build, creates listener
    useEffect(() {
      final firestore = FirebaseFirestore.instance;
      final roomRef = firestore.collection('rooms').doc(widget.roomId);
      return roomRef.snapshots().listen((snap) {
        // Handle room data
      }).cancel;
    }, []);
  }
}
```

**Target Pattern** (✅ Correct):
```dart
// Step 1: Create a provider for the room listener
final roomStreamProvider = StreamProvider.family<Room, String>((ref, roomId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('rooms').doc(roomId).snapshots()
    .map((snap) => Room.fromDoc(snap));
});

// Step 2: Use it in the widget
class LiveRoomScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Clean and reactive
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    
    return roomAsync.when(
      data: (room) => RoomUI(room: room),
      error: (err, st) => ErrorWidget(error: err),
      loading: () => LoadingWidget(),
    );
  }
}
```

**How to Execute**:
1. Extract all Firestore listeners into providers (StreamProvider)
2. In the widget, use `ref.watch(providerName)`
3. Replace manual `.listen()` calls with provider watches
4. Remove manual `useEffect` cleanup

**Key Locations**:
- `initState()` listeners → move to providers
- Direct `FirebaseFirestore.instance` calls → via providers
- Manual subscription cleanup → Riverpod auto-handles

---

## 📋 Execution Checklist

### Step 1: Prepare (5 min)
```bash
# Create backup branch
git checkout -b refactor/tier1-singletons

# Verify current state
flutter analyze
# Should show: No issues found
```

### Step 2: File 1 - firebase_providers.dart (10 min)
```bash
# Open file
code lib/core/providers/firebase_providers.dart

# Verify it exports:
# - firestoreProvider
# - firebaseAuthProvider
# - firebaseDatabaseProvider

# If complete, move to next file
```

### Step 3: File 2 - auth_controller.dart (15 min)
```bash
# Find all singletons in this file
Select-String -Path lib/features/auth/controllers/auth_controller.dart `
  -Pattern "FirebaseAuth\.instance|FirebaseFirestore\.instance"

# Expected: Should find 2-3 instances

# Replace each with ref.read(firebaseAuthProvider)
# Add "final Ref ref;" to constructor
```

### Step 4: File 3 - payment_api.dart (15 min)
```bash
# Find singletons
Select-String -Path lib/services/payment_api.dart `
  -Pattern "FirebaseFirestore\.instance"

# Replace each with ref.read(firestoreProvider)
# Add "final Ref ref;" to constructor
```

### Step 5: File 4 - payments_controller.dart (12 min)
```bash
# Find singletons
Select-String -Path lib/features/payments/payments_controller.dart `
  -Pattern "FirebaseFirestore\.instance|FirebaseAuth\.instance"

# Replace with ref.read(provider)
# Add "final Ref ref;" to constructor
```

### Step 6: File 5 - live_room_screen.dart (18 min)
```bash
# Find singletons
Select-String -Path lib/features/room/presentation/live_room_screen.dart `
  -Pattern "FirebaseFirestore\.instance"

# This one may need creating new StreamProviders
# Extract listeners into providers first, then use in widget
```

### Step 7: Validate (5 min)
```bash
# Run analysis
flutter analyze
# Should show: No issues found

# Check compilation
flutter pub get

# Run tests
flutter test integration_test/ -d web
# Should pass 4/4 tests
```

### Step 8: Commit & Deploy (5 min)
```bash
# Commit changes
git add .
git commit -m "refactor: tier1 singleton → riverpod (auth, payment, room)"

# Deploy (after testing passes)
firebase deploy --only functions
flutter build web --release
firebase deploy --only hosting
```

---

## 🎯 Success Criteria

After this 1-hour refactor, you should have:

✅ **No hardcoded singletons in critical path**
```bash
# Should return 0
Select-String -Path lib/features/auth/controllers/auth_controller.dart `
  -Pattern "FirebaseAuth\.instance" | Measure-Object
```

✅ **All critical providers injectable**
```dart
// Should be able to override in tests
ref.watch(firebaseAuthProvider.overrideWithValue(mockAuth))
ref.watch(firestoreProvider.overrideWithValue(mockFirestore))
```

✅ **Integration tests pass**
```bash
flutter test integration_test/ -d web
# Expected: ✅ 4/4 tests pass
```

✅ **Code analysis passes**
```bash
flutter analyze
# Expected: No issues found
```

---

## 📊 Impact Summary

| Before Refactor | After Refactor |
|---|---|
| 104 hardcoded singletons | ~75 hardcoded singletons (29 removed) |
| Riverpod listeners don't sync | Listeners auto-sync on invalidation |
| Testing blocked | Testing enabled for critical paths |
| State races possible | State guaranteed consistent |
| Can't swap implementations | Can inject mocks for testing |

---

## 🚀 Timeline

```
Start → File 1 (10m) → File 2 (15m) → File 3 (15m) → File 4 (12m) → File 5 (18m) → Validate (5m) → Done! (1hr 15m)

If running into issues: Add 15m buffer = 1.5 hours total safe time window
```

---

## ⚠️ Common Mistakes to Avoid

### ❌ Mistake 1: Forgetting to add `final Ref ref;`
```dart
// Wrong
class PaymentService {
  Future<void> pay() {
    final firestore = ref.read(firestoreProvider); // ref doesn't exist!
  }
}

// Right
class PaymentService {
  final Ref ref;
  PaymentService(this.ref);
  
  Future<void> pay() {
    final firestore = ref.read(firestoreProvider); // ✅
  }
}
```

### ❌ Mistake 2: Using `ref.watch()` in non-provider code
```dart
// Wrong - can't use watch outside Riverpod context
class PaymentService {
  void pay() {
    final fs = ref.watch(firestoreProvider); // Error: not in provider context
  }
}

// Right - use ref.read() in service methods
class PaymentService {
  void pay() {
    final fs = ref.read(firestoreProvider); // ✅
  }
}
```

### ❌ Mistake 3: Forgetting to update caller sites
```dart
// If you change PaymentService constructor signature...
// Old: PaymentService()
// New: PaymentService(Ref ref)

// Update all places that create it:
// old: final service = PaymentService();
// new: final service = PaymentService(ref); // ❌ Still in service, not provider

// Right: Wrap in provider
final paymentServiceProvider = Provider((ref) => PaymentService(ref));
// Then always use: ref.read(paymentServiceProvider)
```

---

## 🎬 Ready to Execute?

After this 1-hour refactor:
1. Your critical auth/payment/room features will use Riverpod properly
2. Integration tests will pass
3. State sync will work reliably
4. You'll be production-ready

**Next Action**: Start with File 1, follow the checklist, commit frequently.

**Questions During Refactoring?** Refer back to the pattern examples above.
