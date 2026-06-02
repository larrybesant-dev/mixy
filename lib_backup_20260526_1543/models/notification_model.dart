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

String? _asNullableString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String content;
  final String? roomId;
  final String? actorId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    this.roomId,
    this.actorId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(String id, Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    final content = _asString(json['content']);
    return NotificationModel(
      id: id,
      userId: _asString(json['userId']),
      type: _asString(json['type'], fallback: 'general'),
      content: content.isEmpty ? _asString(json['body']) : content,
      roomId: _asNullableString(json['roomId']),
      actorId: _asNullableString(json['actorId']),
      isRead: _asBool(json['isRead']),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
