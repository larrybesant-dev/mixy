import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomMemberRole { host, coHost, listener }

class RoomMember {
  final String userId;
  final RoomMemberRole role;
  final Timestamp joinedAt;

  RoomMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory RoomMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomMember(
      userId: data['userId'] ?? '',
      role: RoomMemberRole.values.firstWhere(
        (e) => e.toString() == 'RoomMemberRole.' + (data['role'] ?? 'listener'),
        orElse: () => RoomMemberRole.listener,
      ),
      joinedAt: data['joinedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role.toString().split('.').last,
      'joinedAt': joinedAt,
    };
  }
}
