import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  roomInvite,
  reaction,
  newFollower,
  tip,
  message,
  system,
}

class Notification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? senderId;
  final String? senderName;
  final String? roomId;
  final String? roomName;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime timestamp;

  Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.senderId,
    this.senderName,
    this.roomId,
    this.roomName,
    this.data,
    this.isRead = false,
    required this.timestamp,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.system,
      ),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      senderId: map['senderId'],
      senderName: map['senderName'],
      roomId: map['roomId'],
      roomName: map['roomName'],
      data: map['data'],
      isRead: map['isRead'] ?? false,
      timestamp: _parseTimestamp(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'roomId': roomId,
      'roomName': roomName,
      'data': data,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  Notification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    String? senderId,
    String? senderName,
    String? roomId,
    String? roomName,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? timestamp,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notification &&
        other.id == id &&
        other.userId == userId &&
        other.type == type &&
        other.title == title &&
        other.message == message &&
        other.senderId == senderId &&
        other.senderName == senderName &&
        other.roomId == roomId &&
        other.roomName == roomName &&
        other.data == data &&
        other.isRead == isRead &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        type.hashCode ^
        title.hashCode ^
        message.hashCode ^
        (senderId?.hashCode ?? 0) ^
        (senderName?.hashCode ?? 0) ^
        (roomId?.hashCode ?? 0) ^
        (roomName?.hashCode ?? 0) ^
        (data?.hashCode ?? 0) ^
        isRead.hashCode ^
        timestamp.hashCode;
  }

  @override
  String toString() {
    return 'Notification(id: $id, userId: $userId, type: $type, title: $title, isRead: $isRead, timestamp: $timestamp)';
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
