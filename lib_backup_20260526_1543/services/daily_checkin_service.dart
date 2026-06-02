import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Reward amounts (coins) per streak day: day 1→10, day 2→20 … day 7+→70
int dailyRewardForStreak(int streak) {
  final day = streak.clamp(1, 7);
  return day * 10;
}

class DailyCheckinStatus {
  const DailyCheckinStatus({
    required this.claimed,
    required this.streak,
    required this.reward,
    this.lastCheckin,
  });

  final bool claimed; // already claimed today
  final int streak; // current streak (1 = first day)
  final int reward; // coins to award today
  final DateTime? lastCheckin;
}

class DailyCheckinService {
  DailyCheckinService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Future<DailyCheckinStatus> getStatus(String uid) async {
    // Check wallet root collection first (new domain)
    final walletRef = _db.collection('wallets').doc(uid);
    final walletSnap = await walletRef.get();

    Map<String, dynamic> data = const <String, dynamic>{};
    bool foundInWallet = false;

    if (walletSnap.exists && walletSnap.data() != null) {
      data = walletSnap.data() ?? const <String, dynamic>{};
      if (data.containsKey('lastCheckinDate')) {
        foundInWallet = true;
      }
    }

    // Fallback to users doc if not found in wallet (legacy support)
    if (!foundInWallet) {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        data = userDoc.data() ?? const <String, dynamic>{};
      }
    }

    final raw = data['lastCheckinDate'];
    DateTime? lastDate;
    if (raw is Timestamp) {
      lastDate = raw.toDate();
    } else if (raw is String) {
      lastDate = DateTime.tryParse(raw);
    }

    final streak = (data['checkinStreak'] as num?)?.toInt() ?? 0;
    final today = _dateOnly(DateTime.now());

    if (lastDate != null && _dateOnly(lastDate) == today) {
      // Already claimed today
      return DailyCheckinStatus(
        claimed: true,
        streak: streak,
        reward: dailyRewardForStreak(streak),
        lastCheckin: lastDate,
      );
    }

    // Calculate new streak
    int newStreak;
    if (lastDate != null &&
        _dateOnly(lastDate) == today.subtract(const Duration(days: 1))) {
      // Consecutive day
      newStreak = streak + 1;
    } else {
      // Streak broken or first time
      newStreak = 1;
    }

    return DailyCheckinStatus(
      claimed: false,
      streak: newStreak,
      reward: dailyRewardForStreak(newStreak),
      lastCheckin: lastDate,
    );
  }

  /// Claims the daily check-in reward. Returns true on success.
  /// All coin balance mutations happen server-side via the claimDailyCheckin callable.
  Future<bool> claim(String uid) async {
    final status = await getStatus(uid);
    if (status.claimed) return false;

    try {
      final callable = _functions.httpsCallable('claimDailyCheckin');
      await callable.call<Map<String, dynamic>>({});
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') return false;
      rethrow;
    }
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
