import 'package:cloud_firestore/cloud_firestore.dart';

class SchemaFriendPresence {
  const SchemaFriendPresence({
    required this.friendId,
    required this.isOnline,
    this.roomId,
    this.lastActiveAt,
  });

  final String friendId;
  final bool isOnline;
  final String? roomId;
  final DateTime? lastActiveAt;

  bool get isInRoom => (roomId ?? '').isNotEmpty;

  SchemaFriendPresenceGroup get group {
    if (isInRoom) return SchemaFriendPresenceGroup.inRoom;
    if (isOnline) return SchemaFriendPresenceGroup.online;
    return SchemaFriendPresenceGroup.offline;
  }

  SchemaFriendPresence normalized() {
    if (!isInRoom) {
      return this;
    }

    return copyWith(isOnline: true);
  }

  SchemaFriendPresence copyWith({
    String? friendId,
    bool? isOnline,
    String? roomId,
    bool clearRoomId = false,
    DateTime? lastActiveAt,
    bool clearLastActiveAt = false,
  }) {
    return SchemaFriendPresence(
      friendId: friendId ?? this.friendId,
      isOnline: isOnline ?? this.isOnline,
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      lastActiveAt: clearLastActiveAt
          ? null
          : (lastActiveAt ?? this.lastActiveAt),
    );
  }

  factory SchemaFriendPresence.offline(String friendId) {
    return SchemaFriendPresence(friendId: friendId, isOnline: false);
  }

  static SchemaFriendPresence fromParticipantDocs(
    String friendId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return SchemaFriendPresence.offline(friendId);
    }

    DateTime? latestSeen;
    String? activeRoomId;
    bool hasLiveSignal = false;

    for (final doc in docs) {
      final data = doc.data();
      final userStatus = _asString(data['userStatus']);
      final lastActive = _asDateTime(data['lastActiveAt']);
      final roomId = doc.reference.parent.parent?.id;

      if (lastActive != null &&
          (latestSeen == null || lastActive.isAfter(latestSeen))) {
        latestSeen = lastActive;
        activeRoomId = roomId;
      }

      if (userStatus == 'online' ||
          _asBool(data['camOn']) ||
          _asBool(data['micOn'])) {
        hasLiveSignal = true;
      }
    }

    final isRecentlyActive =
        latestSeen != null &&
        DateTime.now().difference(latestSeen).inMinutes <= 5;

    return SchemaFriendPresence(
      friendId: friendId,
      isOnline: hasLiveSignal || isRecentlyActive,
      roomId: activeRoomId,
      lastActiveAt: latestSeen,
    );
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return fallback;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

enum SchemaFriendPresenceGroup { inRoom, online, offline }
