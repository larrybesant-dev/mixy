import 'package:cloud_firestore/cloud_firestore.dart';

class MicAccessRequestModel {
  final String id;
  final String roomId;
  final String requesterId;
  final String hostId;
  final String status;
  final int priority;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MicAccessRequestModel({
    required this.id,
    required this.roomId,
    required this.requesterId,
    required this.hostId,
    required this.status,
    required this.priority,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  static int _asInt(dynamic value, {int fallback = 100}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  factory MicAccessRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return MicAccessRequestModel(
      id: _asString(json['id']),
      roomId: _asString(json['roomId']),
      requesterId: _asString(json['requesterId']),
      hostId: _asString(json['hostId']),
      status: _asString(json['status'], fallback: 'pending'),
      priority: _asInt(json['priority']),
      expiresAt: parseDate(json['expiresAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isPending => status == 'pending' && !isExpired;

  bool get isClosed =>
      status == 'approved' ||
      status == 'denied' ||
      status == 'expired' ||
      status == 'cancelled';
}
