import 'package:cloud_firestore/cloud_firestore.dart';

String? _asNullableString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map(
          (item) =>
              item is String ? item.trim() : item?.toString().trim() ?? '',
        )
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

class SpeedDateCandidate {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final List<String> interests;

  const SpeedDateCandidate({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.interests = const [],
  });

  factory SpeedDateCandidate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final username = _asNullableString(data['username']);
    return SpeedDateCandidate(
      id: doc.id,
      username:
          (username == null || username.isEmpty) ? 'MixVy User' : username,
      avatarUrl: _asNullableString(data['avatarUrl']),
      bio: _asNullableString(data['bio']),
      interests: _asStringList(data['interests']),
    );
  }
}

class SpeedDatingMatch {
  final String id;
  final List<String> participantIds;
  final Timestamp? createdAt;
  final String? latestRoomId;

  const SpeedDatingMatch({
    required this.id,
    required this.participantIds,
    this.createdAt,
    this.latestRoomId,
  });

  String otherUserId(String selfId) {
    return participantIds.firstWhere(
      (id) => id != selfId,
      orElse: () => selfId,
    );
  }

  factory SpeedDatingMatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SpeedDatingMatch(
      id: doc.id,
      participantIds: _asStringList(data['participantIds']),
      createdAt: data['createdAt'] as Timestamp?,
      latestRoomId: _asNullableString(data['latestRoomId']),
    );
  }
}

class SpeedDateDecisionResult {
  final bool isMatch;
  final String? matchId;

  const SpeedDateDecisionResult({required this.isMatch, this.matchId});
}

/// Result returned from the server-side matchmaking queue.
class SpeedDatingQueueResult {
  final bool matched;
  final String? sessionId;
  final String? partnerId;

  const SpeedDatingQueueResult({
    required this.matched,
    this.sessionId,
    this.partnerId,
  });
}
