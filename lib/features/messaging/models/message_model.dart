import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
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
  if (value is bool) return value;
  if (value is num) return value != 0;

  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .where((e) => e != null)
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

class MessageModel {
  final String id;
  final String? clientmessageId;

  final String conversationId;

  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;

  final String content;

  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? editedAt;

  final bool isDeleted;
  final List<String> readBy;

  /// Message type: 'normal' | 'system' | 'announcement' | 'private'.
  /// Defaults to 'normal' for DM messages.
  final String type;

  MessageModel({
    required this.id,
    this.clientmessageId,
    required this.senderId,
    String? conversationId,
    String? roomId,
    String? senderName,
    this.senderAvatarUrl,
    required this.content,
    DateTime? createdAt,
    DateTime? sentAt,
    this.expiresAt,
    this.editedAt,
    this.isDeleted = false,
    this.readBy = const [],
    this.type = 'normal',
  }) : conversationId = conversationId ?? roomId ?? '',
       senderName = senderName ?? 'Unknown',
       createdAt = createdAt ?? sentAt ?? DateTime.now();

  factory MessageModel.fromJson(Map<String, dynamic> json, String docId) {
    return MessageModel(
      id: docId,
      clientmessageId: _asNullableString(json['clientmessageId']),
      conversationId: _asString(json['conversationId']),
      roomId: _asString(json['roomId']),
      senderId: _asString(json['senderId']),
      senderName: _asString(json['senderName'], fallback: 'Unknown'),
      senderAvatarUrl: _asNullableString(json['senderAvatarUrl']),
      content: _asString(json['content']),
      createdAt: json['createdAt'] != null
          ? _parseDateTime(json['createdAt'])
          : _parseDateTime(json['sentAt']),
      expiresAt: json['expiresAt'] == null
          ? null
          : _parseDateTime(json['expiresAt']),
      editedAt: json['editedAt'] == null
          ? null
          : _parseDateTime(json['editedAt']),
      isDeleted: _asBool(json['isDeleted']),
      readBy: _asStringList(json['readBy']),
      type: _asString(json['type'], fallback: 'normal'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'clientmessageId': clientmessageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'content': content,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'isDeleted': isDeleted,
      'readBy': readBy,
    };
  }

  bool isRead(String userId) => readBy.contains(userId);

  MessageModel copyWith({
    String? id,
    String? clientmessageId,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? content,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? editedAt,
    bool? isDeleted,
    List<String>? readBy,
    String? type,
  }) {
    return MessageModel(
      id: id ?? this.id,
      clientmessageId: clientmessageId ?? this.clientmessageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      readBy: readBy ?? this.readBy,
      type: type ?? this.type,
    );
  }

  String get roomId => conversationId;

  DateTime get sentAt => createdAt;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
