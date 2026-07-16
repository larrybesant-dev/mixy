import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/firebase_providers.dart';

const int DAILY_FREE_GIFT_LIMIT = 5;

class FreeGiftAllowance {
  final int remainingToday;
  final DateTime resetTime; // Midnight tomorrow

  const FreeGiftAllowance({
    required this.remainingToday,
    required this.resetTime,
  });

  bool get canSendFreeGift => remainingToday > 0;

  factory FreeGiftAllowance.fromSnapshot(DocumentSnapshot? snap, DateTime now) {
    if (snap == null || !snap.exists) {
      // New user: full allowance
      return FreeGiftAllowance(
        remainingToday: DAILY_FREE_GIFT_LIMIT,
        resetTime: _getMidnightTomorrow(now),
      );
    }

    final data = snap.data() as Map<String, dynamic>? ?? {};
    final lastResetRaw = data['lastReset'];
    final lastReset = lastResetRaw is Timestamp
        ? lastResetRaw.toDate()
        : DateTime.tryParse(lastResetRaw as String? ?? '');

    // If last reset was before today, reset counter
    if (lastReset == null || _isBeforeToday(lastReset, now)) {
      return FreeGiftAllowance(
        remainingToday: DAILY_FREE_GIFT_LIMIT,
        resetTime: _getMidnightTomorrow(now),
      );
    }

    // Otherwise, decrement from stored count
    final remaining = (data['remainingToday'] as int?) ?? DAILY_FREE_GIFT_LIMIT;
    return FreeGiftAllowance(
      remainingToday: remaining,
      resetTime: lastReset.add(const Duration(days: 1)),
    );
  }

  static DateTime _getMidnightTomorrow(DateTime now) {
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  static bool _isBeforeToday(DateTime date, DateTime now) {
    return date.year < now.year ||
        (date.year == now.year && date.month < now.month) ||
        (date.year == now.year && date.month == now.month && date.day < now.day);
  }
}

/// Watches the current user's free gift allowance for today.
final freeGiftAllowanceProvider = StreamProvider<FreeGiftAllowance>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(FreeGiftAllowance(
          remainingToday: 0,
          resetTime: DateTime.now().add(const Duration(days: 1)),
        ));
      }

      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gift_tracking')
          .doc('allowance')
          .snapshots()
          .map((snap) => FreeGiftAllowance.fromSnapshot(snap, DateTime.now()));
    },
    loading: () => Stream.value(FreeGiftAllowance(
      remainingToday: DAILY_FREE_GIFT_LIMIT,
      resetTime: DateTime.now().add(const Duration(days: 1)),
    )),
    error: (_, __) => Stream.value(FreeGiftAllowance(
      remainingToday: 0,
      resetTime: DateTime.now().add(const Duration(days: 1)),
    )),
  );
});

/// Decrement allowance after successful gift send (client-side).
/// The Cloud Function will also validate and update server-side.
final useGiftAllowanceFunction = FutureProvider.autoDispose<void>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.whenData((u) => u).value;

  if (user == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('gift_tracking')
      .doc('allowance')
      .update({
        'remainingToday': FieldValue.increment(-1),
        'lastReset': FieldValue.serverTimestamp(),
      })
      .catchError((_) {
        // Document doesn't exist, create it
        return FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('gift_tracking')
            .doc('allowance')
            .set({
              'remainingToday': DAILY_FREE_GIFT_LIMIT - 1,
              'lastReset': FieldValue.serverTimestamp(),
            });
      });
});
