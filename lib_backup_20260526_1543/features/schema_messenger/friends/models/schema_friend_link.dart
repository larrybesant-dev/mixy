import 'package:cloud_firestore/cloud_firestore.dart';

class SchemaFriendLink {
  const SchemaFriendLink({
    required this.id,
    required this.users,
    required this.status,
    required this.requestedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final List<String> users;
  final String status;
  final String requestedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String otherUserId(String currentUserId) {
    for (final userId in users) {
      if (userId != currentUserId) {
        return userId;
      }
    }
    return '';
  }

  bool includesUser(String userId) => users.contains(userId);

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';
  bool get isBlocked => status == 'blocked';

  factory SchemaFriendLink.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SchemaFriendLink(
      id: doc.id,
      users: _asUsers(data['users']),
      status: _asString(data['status'], fallback: 'pending'),
      requestedBy: _asString(data['requestedBy']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  static String canonicalIdFor(String firstUserId, String secondUserId) {
    final ids = [firstUserId.trim(), secondUserId.trim()]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  static List<String> sortedUsers(String firstUserId, String secondUserId) {
    final ids = [firstUserId.trim(), secondUserId.trim()]..sort();
    return ids;
  }

  static List<String> _asUsers(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item is String ? item.trim() : '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
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

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
