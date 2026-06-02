import 'package:cloud_firestore/cloud_firestore.dart';

class FriendshipModel {
  const FriendshipModel({
    required this.id,
    required this.userA,
    required this.userB,
    required this.status,
    required this.createdAt,
    this.requestedBy,
    this.updatedAt,
  });

  final String id;
  final String userA;
  final String userB;
  final String status;
  final DateTime createdAt;
  final String? requestedBy;
  final DateTime? updatedAt;

  static String canonicalIdFor(String firstUserId, String secondUserId) {
    final ids = [firstUserId.trim(), secondUserId.trim()]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  static ({String userA, String userB}) sortedPair(
    String firstUserId,
    String secondUserId,
  ) {
    final ids = [firstUserId.trim(), secondUserId.trim()]..sort();
    return (userA: ids[0], userB: ids[1]);
  }

  factory FriendshipModel.fromJson(String id, Map<String, dynamic> json) {
    return FriendshipModel(
      id: id,
      userA: _asString(json['userA']),
      userB: _asString(json['userB']),
      status: _asString(json['status'], fallback: 'pending'),
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      requestedBy: _asNullableString(json['requestedBy']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  String otherUserId(String currentUserId) {
    final normalizedUserId = currentUserId.trim();
    if (normalizedUserId == userA) return userB;
    if (normalizedUserId == userB) return userA;
    return '';
  }

  bool involvesUser(String userId) {
    final normalizedUserId = userId.trim();
    return userA == normalizedUserId || userB == normalizedUserId;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userA': userA,
      'userB': userB,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'requestedBy': requestedBy,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  static String? _asNullableString(dynamic value) {
    final parsed = _asString(value);
    return parsed.isEmpty ? null : parsed;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
