import 'package:cloud_firestore/cloud_firestore.dart';

class ReactionModel {
  final String userId;
  final String emoji;
  final DateTime timestamp;

  ReactionModel({
    required this.userId,
    required this.emoji,
    required this.timestamp,
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

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    return ReactionModel(
      userId: _asString(json['userId']),
      emoji: _asString(json['emoji']),
      timestamp: _parseDateTime(json['timestamp']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'emoji': emoji,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
