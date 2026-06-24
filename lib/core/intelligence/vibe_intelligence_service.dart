/// Vibe Intelligence Service
/// Powers Mix & Mingle's self-improving discovery systems:
///   #1 — Vibe Affinity tracking (vibeHistory writes to Firestore)
///   #7 — Auto vibe suggestion logic (computed client-side)
///  #10 — Behavior tag helpers (mirrored by Cloud Function nightly)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────

final vibeIntelligenceServiceProvider =
    Provider<VibeIntelligenceService>((ref) {
  return VibeIntelligenceService(FirebaseFirestore.instance);
});

// ─────────────────────────────────────────────────────────────────────────────

class VibeIntelligenceService {
  final FirebaseFirestore _db;

  const VibeIntelligenceService(this._db);

  // ── #1: Vibe Affinity ─────────────────────────────────────────────────────

  /// Call this every time a user joins a room with a vibeTag.
  /// Increments the vibe counter in Firestore atomically.
  Future<void> recordVibeJoin({
    required String userId,
    required String vibeTag,
  }) async {
    if (vibeTag.isEmpty) return;
    await _db.collection('users').doc(userId).update({
      'vibeHistory.$vibeTag': FieldValue.increment(1),
    });
  }

  // ── #7: Vibe Suggestion ───────────────────────────────────────────────────

  /// Returns a suggestion nudge string if the user has been stuck in
  /// the same vibe ≥ [threshold] times, otherwise null.
  ///
  /// e.g. "You've been Chill lately — try a Hype room 🔥"
  String? getVibeSuggestion(UserProfile p, {int threshold = 3}) {
    final history = p.vibeHistory;
    if (history.isEmpty) return null;

    final top = p.topVibe;
    final topCount = p.topVibeCount;
    if (top == null || topCount < threshold) return null;

    // Find an alternative vibe to suggest
    final alternatives = _kVibes.where((v) => v != top).toList()
      ..sort(); // deterministic across builds
    if (alternatives.isEmpty) return null;

    // Prefer a vibe the user has never tried
    final neverTried =
        alternatives.where((v) => !history.containsKey(v)).toList();

    final suggestion = neverTried.isNotEmpty
        ? neverTried.first
        : alternatives.reduce(
            (a, b) => (history[a] ?? 0) < (history[b] ?? 0) ? a : b,
          );

    final emojis = {
      'Chill': '🌊',
      'Hype': '🔥',
      'Deep Talk': '🧠',
      'Late Night': '🌙',
      'Study': '📚',
      'Party': '🎉',
    };

    return "You've been $top lately — try a $suggestion room ${emojis[suggestion] ?? '✨'}";
  }

  // ── #10: Behavior Tag Computation (client-side mirror) ───────────────────

  /// Computes behavior tags from a user's profile metrics.
  /// The Cloud Function runs this nightly and writes the results back to
  /// Firestore. This client-side version enables instant previews during
  /// onboarding and testing.
  List<String> computeBehaviorTags(UserProfile p) {
    final tags = <String>[];

    // Activity tiers
    if (p.roomsHostedCount >= 10) {
      tags.add('Super Host');
    } else if (p.roomsHostedCount >= 3) {
      tags.add('Rising Host');
    }

    if (p.totalRoomsJoined >= 50) {
      tags.add('Room Regular');
    } else if (p.totalRoomsJoined >= 20) {
      tags.add('Social Butterfly');
    }

    if (p.eventsAttended >= 10) tags.add('Event Lover');

    // Timing-based
    final lastActive = p.updatedAt;
    if (lastActive.hour >= 22 || lastActive.hour <= 3) tags.add('Night Owl');
    if (lastActive.hour >= 6 && lastActive.hour <= 10) tags.add('Early Bird');

    // Vibe-based
    final top = p.topVibe;
    if (top != null && p.topVibeCount >= 5) {
      tags.add('$top Enthusiast');
    }
    if (p.vibeHistory.length >= 4) tags.add('Vibe Explorer');

    // Social proof
    if (p.communityRating >= 4.5) tags.add('Top Rated');
    if (p.followersCount >= 100) tags.add('Influencer');

    // Energy
    if (p.energyScore >= 90) {
      tags.add('High Energy');
    } else if (p.energyScore >= 50) {
      tags.add('Active Member');
    }

    return tags.take(5).toList(); // cap at 5 tags
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const _kVibes = [
    'Chill',
    'Hype',
    'Deep Talk',
    'Late Night',
    'Study',
    'Party',
  ];
}
