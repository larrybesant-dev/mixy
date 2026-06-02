import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SocialActivity {
  const SocialActivity({
    required this.id,
    required this.userId,
    required this.type,
    this.targetId,
    required this.timestamp,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String userId;
  final String type;
  final String? targetId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  factory SocialActivity.fromJson(String id, Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    DateTime resolvedTimestamp;
    if (rawTimestamp is Timestamp) {
      resolvedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is DateTime) {
      resolvedTimestamp = rawTimestamp;
    } else {
      resolvedTimestamp = DateTime.now();
    }

    return SocialActivity(
      id: id,
      userId: _asString(json['userId']),
      type: _asString(json['type']),
      targetId: _asNullableString(json['targetId']),
      timestamp: resolvedTimestamp,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return fallback;
  }

  static String? _asNullableString(dynamic value) {
    final normalized = _asString(value);
    return normalized.isEmpty ? null : normalized;
  }

  String get label {
    switch (type) {
      case 'joined_room':
        return 'Joined room';
      case 'left_room':
        return 'Left room';
      case 'went_live':
        return 'Went live';
      case 'updated_profile':
        return 'Updated profile';
      case 'followed_user':
        return 'Followed someone';
      default:
        return 'Recent activity';
    }
  }

  String get value {
    switch (type) {
      case 'joined_room':
      case 'left_room':
        return _asNullableString(metadata['roomName']) ??
            targetId ??
            'Live room';
      case 'went_live':
        return _asNullableString(metadata['detail']) ?? 'Started voice/video';
      case 'updated_profile':
        return _asNullableString(metadata['detail']) ?? 'Profile refreshed';
      case 'followed_user':
        return _asNullableString(metadata['targetUsername']) ??
            targetId ??
            'New connection';
      default:
        return _asNullableString(metadata['detail']) ?? 'Social update';
    }
  }

  IconData get icon {
    switch (type) {
      case 'joined_room':
        return Icons.login_rounded;
      case 'left_room':
        return Icons.logout_rounded;
      case 'went_live':
        return Icons.videocam_rounded;
      case 'updated_profile':
        return Icons.edit_outlined;
      case 'followed_user':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color get accent {
    switch (type) {
      case 'joined_room':
      case 'went_live':
        return const Color(0xFFC45E7A);
      case 'updated_profile':
        return const Color(0xFFD4A853);
      case 'followed_user':
        return const Color(0xFF7C5FFF);
      default:
        return const Color(0xFFB09080);
    }
  }
}
