import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../../models/user_model.dart';

/// Top 10 users by coinBalance — displayed on the dashboard leaderboard strip.
/// This is ambient discovery data, so a one-shot load is enough.
final leaderboardProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final snapshot = await ref
      .watch(firestoreProvider)
      .collection('users')
      .orderBy('coinBalance', descending: true)
      .limit(10)
      .get();
  return snapshot.docs
      .map((d) => UserModel.fromFirestore(d))
      .toList(growable: false);
});




