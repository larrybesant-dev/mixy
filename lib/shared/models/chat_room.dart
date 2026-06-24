import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final bool isTyping;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCounts,
    this.isTyping = false,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id'] as String? ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
      unreadCounts: Map<String, int>.from(map['unreadCounts'] ?? {}),
      isTyping: map['isTyping'] as bool? ?? false,
    );
  }

  factory ChatRoom.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return ChatRoom.fromMap(data);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCounts': unreadCounts,
      'isTyping': isTyping,
    };
  }

  ChatRoom copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCounts,
    bool? isTyping,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRoom &&
        other.id == id &&
        other.participants == participants &&
        other.lastMessage == lastMessage &&
        other.lastMessageTime == lastMessageTime &&
        other.unreadCounts == unreadCounts &&
        other.isTyping == isTyping;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        participants.hashCode ^
        lastMessage.hashCode ^
        lastMessageTime.hashCode ^
        unreadCounts.hashCode ^
        isTyping.hashCode;
  }

  @override
  String toString() {
    return 'ChatRoom(id: $id, participants: $participants, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime, unreadCounts: $unreadCounts, isTyping: $isTyping)';
  }
}
