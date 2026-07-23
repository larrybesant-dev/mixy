import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a candidate for speed dating discovery
class SpeedDateCandidate {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int? age;
  final String? bio;
  final bool? isOnline;
  final DateTime? lastActive;

  SpeedDateCandidate({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.age,
    this.bio,
    this.isOnline,
    this.lastActive,
  });

  factory SpeedDateCandidate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SpeedDateCandidate(
      id: doc.id,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      age: data['age'] as int?,
      bio: data['bio'] as String?,
      isOnline: data['isOnline'] as bool? ?? false,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'age': age,
        'bio': bio,
        'isOnline': isOnline,
        'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      };
}

/// Represents a mutual match from speed dating
class SpeedDatingMatch {
  final String id;
  final List<String> participantIds;
  final DateTime createdAt;
  final String source; // 'speed_dating', 'persistent_discovery', etc.
  final bool isActive; // true if match is still valid

  SpeedDatingMatch({
    required this.id,
    required this.participantIds,
    required this.createdAt,
    required this.source,
    this.isActive = true,
  });

  factory SpeedDatingMatch.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SpeedDatingMatch(
      id: doc.id,
      participantIds: List<String>.from(
        (data['participantIds'] as List<dynamic>?) ?? [],
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String? ?? 'unknown',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'participantIds': participantIds,
        'createdAt': Timestamp.fromDate(createdAt),
        'source': source,
        'isActive': isActive,
      };
}
