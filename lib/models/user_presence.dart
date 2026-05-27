import 'package:cloud_firestore/cloud_firestore.dart';

class UserPresence {
  final bool isOnline;
  final DateTime? lastSeen;
  final String? currentRoomId;

  const UserPresence({
    required this.isOnline,
    this.lastSeen,
    this.currentRoomId,
  });

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    DateTime? parsedLastSeen;
    final lastSeenRaw = json['lastSeen'] ?? json['lastActiveAt'];
    if (lastSeenRaw is Timestamp) {
      parsedLastSeen = lastSeenRaw.toDate();
    } else if (lastSeenRaw is String) {
      parsedLastSeen = DateTime.tryParse(lastSeenRaw);
    } else if (lastSeenRaw is int) {
      parsedLastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw);
    }

    return UserPresence(
      isOnline: json['isOnline'] == true || json['online'] == true,
      lastSeen: parsedLastSeen,
      currentRoomId: json['currentRoomId']?.toString() ?? json['roomId']?.toString() ?? json['inRoom']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'isOnline': isOnline,
    'lastSeen': lastSeen?.toIso8601String(),
    'currentRoomId': currentRoomId,
  };
}
