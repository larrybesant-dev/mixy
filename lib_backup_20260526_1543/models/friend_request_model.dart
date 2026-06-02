import 'package:cloud_firestore/cloud_firestore.dart';

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

class FriendRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String status;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(String id, Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return FriendRequestModel(
      id: id,
      fromUserId: _asString(json['fromUserId']),
      toUserId: _asString(json['toUserId']),
      status: _asString(json['status'], fallback: 'pending'),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
