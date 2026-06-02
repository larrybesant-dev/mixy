import 'package:cloud_firestore/cloud_firestore.dart';

/// Schema model for a [conversations/{id}] Firestore document.
///
/// Allowed Fields: participantIds, type, status, lastMessageAt,
///   lastMessagePreview, lastMessageSenderId, lastMessageId, pinnedBy,
///   groupName, groupAvatarUrl, participantNames, lastReadAt, isArchived, createdAt.
/// Forbidden Fields: users/{uid} subdocuments, wallet fields,
///   verification fields, adult_content fields.
class SchemaConversation {
  const SchemaConversation({
    required this.id,
    required this.participantIds,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.isArchived,
    required this.pinnedBy,
    required this.lastReadAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.lastMessageId,
    this.groupName,
    this.groupAvatarUrl,
  });

  final String id;
  final List<String> participantIds;
  final String type; // 'direct' | 'group'
  final String status; // 'active' | 'pending' | 'archived'
  final DateTime createdAt;
  final bool isArchived;
  final List<String> pinnedBy;
  final Map<String, DateTime> lastReadAt; // {userId: lastReadTime}
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final String? lastMessageId;
  final String? groupName;
  final String? groupAvatarUrl;

  bool get isDirect => type == 'direct';
  bool get isGroup => type == 'group';
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  bool hasUnreadFor(String userId) {
    final latestMessageAt = lastMessageAt;
    if (latestMessageAt == null) {
      return false;
    }
    final readAt = lastReadAt[userId];
    return readAt == null || readAt.isBefore(latestMessageAt);
  }

  bool isPinnedFor(String userId) => pinnedBy.contains(userId);

  factory SchemaConversation.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SchemaConversation(
      id: doc.id,
      participantIds: _asStringList(data['participantIds']),
      type: _asString(data['type'], fallback: 'direct'),
      status: _asString(data['status'], fallback: 'active'),
      createdAt: _asDateTime(data['createdAt']),
      isArchived: _asBool(data['isArchived']),
      pinnedBy: _asStringList(data['pinnedBy']),
      lastReadAt: _asLastReadAt(data['lastReadAt']),
      lastMessageAt: _asNullableDateTime(data['lastMessageAt']),
      lastMessagePreview: _asNullableString(data['lastMessagePreview']),
      lastMessageSenderId: _asNullableString(data['lastMessageSenderId']),
      lastMessageId: _asNullableString(data['lastMessageId']),
      groupName: _asNullableString(data['groupName']),
      groupAvatarUrl: _asNullableString(data['groupAvatarUrl']),
    );
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  static String? _asNullableString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map(
            (item) =>
                item is String ? item.trim() : item?.toString().trim() ?? '',
          )
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2020);
    return DateTime(2020);
  }

  static DateTime? _asNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, DateTime> _asLastReadAt(dynamic value) {
    if (value is! Map) return const <String, DateTime>{};
    final result = <String, DateTime>{};
    value.forEach((key, raw) {
      if (key is String) {
        result[key] = _asDateTime(raw);
      }
    });
    return result;
  }
}
