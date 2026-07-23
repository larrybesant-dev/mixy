import 'package:cloud_firestore/cloud_firestore.dart';

class SwipeHistory {
  final String id;
  final String userId;
  final String candidateId;
  final bool isLike;
  final DateTime createdAt;
  final bool isMutual; // true if candidate also liked userId

  SwipeHistory({
    required this.id,
    required this.userId,
    required this.candidateId,
    required this.isLike,
    required this.createdAt,
    this.isMutual = false,
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'candidateId': candidateId,
        'isLike': isLike,
        'createdAt': Timestamp.fromDate(createdAt),
        'isMutual': isMutual,
      };

  factory SwipeHistory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SwipeHistory(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      candidateId: data['candidateId'] as String? ?? '',
      isLike: data['isLike'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMutual: data['isMutual'] as bool? ?? false,
    );
  }
}

class ProfileView {
  final String id;
  final String viewerId;
  final String viewedUserId;
  final DateTime createdAt;
  final String? context; // e.g., 'discovery', 'message', 'profile'

  ProfileView({
    required this.id,
    required this.viewerId,
    required this.viewedUserId,
    required this.createdAt,
    this.context,
  });

  Map<String, dynamic> toFirestore() => {
        'viewerId': viewerId,
        'viewedUserId': viewedUserId,
        'createdAt': Timestamp.fromDate(createdAt),
        'context': context,
      };

  factory ProfileView.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ProfileView(
      id: doc.id,
      viewerId: data['viewerId'] as String? ?? '',
      viewedUserId: data['viewedUserId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      context: data['context'] as String?,
    );
  }
}
