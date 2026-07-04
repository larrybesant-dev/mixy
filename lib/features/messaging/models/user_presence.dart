import 'package:cloud_firestore/cloud_firestore.dart';

class UserPresence {
  final String userId;
  final DateTime lastActiveAt;
  final bool isOnline;
  final String? lastLocation; // For future geolocation features
  final String? currentActivity; // e.g., 'chatting', 'browsing'

  const UserPresence({
    required this.userId,
    required this.lastActiveAt,
    this.isOnline = false,
    this.lastLocation,
    this.currentActivity,
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'lastActiveAt': Timestamp.fromDate(lastActiveAt),
        'isOnline': isOnline,
        'lastLocation': lastLocation,
        'currentActivity': currentActivity,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory UserPresence.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final lastActiveTimestamp = data['lastActiveAt'] as Timestamp?;

    return UserPresence(
      userId: data['userId'] as String? ?? doc.id,
      lastActiveAt: lastActiveTimestamp?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] as bool? ?? false,
      lastLocation: data['lastLocation'] as String?,
      currentActivity: data['currentActivity'] as String?,
    );
  }

  String getStatusText() {
    if (isOnline) return 'Online now';

    final diff = DateTime.now().difference(lastActiveAt);
    if (diff.inMinutes < 1) return 'Active now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return 'Last seen ${lastActiveAt.month}/${lastActiveAt.day}';
  }

  UserPresence copyWith({
    String? userId,
    DateTime? lastActiveAt,
    bool? isOnline,
    String? lastLocation,
    String? currentActivity,
  }) =>
      UserPresence(
        userId: userId ?? this.userId,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        isOnline: isOnline ?? this.isOnline,
        lastLocation: lastLocation ?? this.lastLocation,
        currentActivity: currentActivity ?? this.currentActivity,
      );
}
