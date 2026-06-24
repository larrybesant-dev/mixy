import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Room statistics model
class RoomStatistics {
  final String roomId;
  final int totalVisitors;
  final int peakConcurrentUsers;
  final Duration averageSessionDuration;
  final DateTime createdAt;
  final DateTime? lastActivityAt;
  final int totalMessagesCount;
  final int totalRecordingsCount;
  final double averageUserRating;
  final Map<String, int> hourlyVisitors;

  RoomStatistics({
    required this.roomId,
    required this.totalVisitors,
    required this.peakConcurrentUsers,
    required this.averageSessionDuration,
    required this.createdAt,
    this.lastActivityAt,
    required this.totalMessagesCount,
    required this.totalRecordingsCount,
    required this.averageUserRating,
    required this.hourlyVisitors,
  });

  factory RoomStatistics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomStatistics(
      roomId: doc.id,
      totalVisitors: data['totalVisitors'] ?? 0,
      peakConcurrentUsers: data['peakConcurrentUsers'] ?? 0,
      averageSessionDuration: Duration(
        seconds: data['averageSessionDurationSeconds'] ?? 0,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate(),
      totalMessagesCount: data['totalMessagesCount'] ?? 0,
      totalRecordingsCount: data['totalRecordingsCount'] ?? 0,
      averageUserRating: (data['averageUserRating'] ?? 0.0).toDouble(),
      hourlyVisitors: Map<String, int>.from(data['hourlyVisitors'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalVisitors': totalVisitors,
      'peakConcurrentUsers': peakConcurrentUsers,
      'averageSessionDurationSeconds': averageSessionDuration.inSeconds,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActivityAt':
          lastActivityAt != null ? Timestamp.fromDate(lastActivityAt!) : null,
      'totalMessagesCount': totalMessagesCount,
      'totalRecordingsCount': totalRecordingsCount,
      'averageUserRating': averageUserRating,
      'hourlyVisitors': hourlyVisitors,
    };
  }
}

/// User engagement model
class UserEngagement {
  final String userId;
  final String userName;
  final DateTime firstJoinedAt;
  final DateTime lastActivityAt;
  final int totalSessions;
  final Duration totalTimeInRoom;
  final int messagesCount;
  final int recordingsCount;
  final double userRating;

  UserEngagement({
    required this.userId,
    required this.userName,
    required this.firstJoinedAt,
    required this.lastActivityAt,
    required this.totalSessions,
    required this.totalTimeInRoom,
    required this.messagesCount,
    required this.recordingsCount,
    required this.userRating,
  });

  factory UserEngagement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserEngagement(
      userId: doc.id,
      userName: data['userName'] ?? 'Unknown',
      firstJoinedAt:
          (data['firstJoinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityAt:
          (data['lastActivityAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalSessions: data['totalSessions'] ?? 0,
      totalTimeInRoom: Duration(
        seconds: data['totalTimeInRoomSeconds'] ?? 0,
      ),
      messagesCount: data['messagesCount'] ?? 0,
      recordingsCount: data['recordingsCount'] ?? 0,
      userRating: (data['userRating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'firstJoinedAt': Timestamp.fromDate(firstJoinedAt),
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'totalSessions': totalSessions,
      'totalTimeInRoomSeconds': totalTimeInRoom.inSeconds,
      'messagesCount': messagesCount,
      'recordingsCount': recordingsCount,
      'userRating': userRating,
    };
  }
}

/// Analytics & Statistics Service
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record user join event
  Future<void> recordUserJoin(String roomId, String userId) async {
    await _firestore.collection('rooms').doc(roomId).collection('events').add({
      'type': 'user_join',
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Record user leave event
  Future<void> recordUserLeave(String roomId, String userId) async {
    await _firestore.collection('rooms').doc(roomId).collection('events').add({
      'type': 'user_leave',
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Record message sent
  Future<void> recordMessageSent(String roomId, String userId) async {
    await _firestore.collection('rooms').doc(roomId).collection('events').add({
      'type': 'message_sent',
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Record recording created
  Future<void> recordRecordingCreated(
    String roomId,
    String userId,
    int fileSize,
  ) async {
    await _firestore.collection('rooms').doc(roomId).collection('events').add({
      'type': 'recording_created',
      'userId': userId,
      'fileSize': fileSize,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get room statistics
  Future<RoomStatistics?> getRoomStatistics(String roomId) async {
    try {
      final doc =
          await _firestore.collection('room_statistics').doc(roomId).get();
      if (!doc.exists) return null;
      return RoomStatistics.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Get user engagement
  Future<UserEngagement?> getUserEngagement(
    String roomId,
    String userId,
  ) async {
    try {
      final doc = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('user_engagement')
          .doc(userId)
          .get();
      if (!doc.exists) return null;
      return UserEngagement.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Get room statistics stream
  Stream<RoomStatistics?> getRoomStatisticsStream(String roomId) {
    return _firestore
        .collection('room_statistics')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return RoomStatistics.fromFirestore(snapshot);
    });
  }

  /// Get top users in room by engagement
  Stream<List<UserEngagement>> getTopUsersInRoomStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('user_engagement')
        .orderBy('totalTimeInRoomSeconds', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserEngagement.fromFirestore(doc))
          .toList();
    });
  }

  /// Get recent activity
  Stream<List<Map<String, dynamic>>> getRecentActivityStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'type': data['type'],
          'userId': data['userId'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }
}

/// Provider for Analytics Service
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Provider for room statistics
final roomStatisticsProvider =
    StreamProvider.family<RoomStatistics?, String>((ref, roomId) {
  final service = ref.watch(analyticsServiceProvider);
  return service.getRoomStatisticsStream(roomId);
});

/// Provider for top users
final topUsersInRoomProvider =
    StreamProvider.family<List<UserEngagement>, String>((ref, roomId) {
  final service = ref.watch(analyticsServiceProvider);
  return service.getTopUsersInRoomStream(roomId);
});

/// Provider for recent activity
final recentActivityProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  final service = ref.watch(analyticsServiceProvider);
  return service.getRecentActivityStream(roomId);
});
