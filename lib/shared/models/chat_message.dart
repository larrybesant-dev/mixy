import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart' show MessageStatus;

/// Message context types
enum MessageContext {
  direct, // Direct message between two users
  room, // Voice/video room message
  group, // Group chat message
  speedDating, // Speed dating session message
}

/// Message content types
enum MessageContentType {
  text, // Text message
  image, // Image attachment
  video, // Video attachment
  audio, // Audio attachment
  system, // System notification
  emote, // Emote/reaction
  sticker, // Sticker
  file, // File attachment
}

/// Unified message model for all chat contexts
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final DateTime timestamp;

  // Context fields
  final MessageContext context;
  final String? roomId; // For room/group messages
  final String? receiverId; // For direct messages
  final String? conversationId; // For DM threads

  // Type & Status
  final MessageContentType contentType;
  final MessageStatus status;

  // Features
  final bool isDeleted;
  final bool isRead;
  final bool isPinned;
  final bool isEdited;
  final DateTime? editedAt;
  final String? replyToId;
  final List<String> reactions;
  final List<String> mentionedUserIds;
  final Map<String, dynamic>? metadata;

  // Media
  final String? imageUrl;
  final String? mediaUrl;
  final String? thumbnailUrl;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.content,
    required this.timestamp,
    this.context = MessageContext.direct,
    this.roomId,
    this.receiverId,
    this.conversationId,
    this.contentType = MessageContentType.text,
    this.status = MessageStatus.sent,
    this.isDeleted = false,
    this.isRead = false,
    this.isPinned = false,
    this.isEdited = false,
    this.editedAt,
    this.replyToId,
    this.reactions = const [],
    this.mentionedUserIds = const [],
    this.metadata,
    this.imageUrl,
    this.mediaUrl,
    this.thumbnailUrl,
  });

  /// System message factory for room notifications
  factory ChatMessage.system({
    required String content,
    required String roomId,
    String? senderId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: '', // Will be set by Firestore
      senderId: senderId ?? 'system',
      senderName: 'System',
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      context: MessageContext.room,
      roomId: roomId,
      contentType: MessageContentType.system,
      metadata: metadata,
    );
  }

  /// Create from Firestore map
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String? ?? '',
      senderId: map['senderId'] as String? ?? map['userId'] as String? ?? '',
      senderName: map['senderName'] as String? ??
          map['displayName'] as String? ??
          'Unknown',
      senderAvatarUrl:
          map['senderAvatarUrl'] as String? ?? map['userAvatar'] as String?,
      content: map['content'] as String? ??
          map['message'] as String? ??
          map['text'] as String? ??
          '',
      timestamp: _parseTimestamp(map['timestamp']),
      context: _parseContext(
          map['context'] as String? ?? map['roomType'] as String?),
      roomId: map['roomId'] as String?,
      receiverId: map['receiverId'] as String?,
      conversationId: map['conversationId'] as String?,
      contentType: _parseContentType(
          map['contentType'] as String? ?? map['type'] as String?),
      status: _parseStatus(map['status'] as String?),
      isDeleted: map['isDeleted'] as bool? ?? false,
      isRead: map['isRead'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
      isEdited: map['isEdited'] as bool? ?? false,
      editedAt:
          map['editedAt'] != null ? _parseTimestamp(map['editedAt']) : null,
      replyToId:
          map['replyToId'] as String? ?? map['replyToMessageId'] as String?,
      reactions: List<String>.from(map['reactions'] ?? []),
      mentionedUserIds: List<String>.from(map['mentionedUserIds'] ?? []),
      metadata: map['metadata'] as Map<String, dynamic>?,
      imageUrl: map['imageUrl'] as String?,
      mediaUrl: map['mediaUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
    );
  }

  /// Create from Firestore document
  factory ChatMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    data['id'] = doc.id;
    return ChatMessage.fromMap(data);
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'context': context.name,
      'roomId': roomId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'contentType': contentType.name,
      'status': status.name,
      'isDeleted': isDeleted,
      'isRead': isRead,
      'isPinned': isPinned,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'replyToId': replyToId,
      'reactions': reactions,
      'mentionedUserIds': mentionedUserIds,
      'metadata': metadata,
      'imageUrl': imageUrl,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  /// Firestore-compatible serialization (aliases for legacy fields)
  Map<String, dynamic> toFirestore() {
    final map = toMap();
    // Add legacy field aliases for backward compatibility
    map['userId'] = senderId;
    map['displayName'] = senderName;
    map['message'] = content;
    map['type'] = contentType.name;
    return map;
  }

  /// Copy with method
  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? content,
    DateTime? timestamp,
    MessageContext? context,
    String? roomId,
    String? receiverId,
    String? conversationId,
    MessageContentType? contentType,
    MessageStatus? status,
    bool? isDeleted,
    bool? isRead,
    bool? isPinned,
    bool? isEdited,
    DateTime? editedAt,
    String? replyToId,
    List<String>? reactions,
    List<String>? mentionedUserIds,
    Map<String, dynamic>? metadata,
    String? imageUrl,
    String? mediaUrl,
    String? thumbnailUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      context: context ?? this.context,
      roomId: roomId ?? this.roomId,
      receiverId: receiverId ?? this.receiverId,
      conversationId: conversationId ?? this.conversationId,
      contentType: contentType ?? this.contentType,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      isRead: isRead ?? this.isRead,
      isPinned: isPinned ?? this.isPinned,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      metadata: metadata ?? this.metadata,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  // Helper methods
  bool get isSystemMessage => contentType == MessageContentType.system;
  bool get hasMedia => mediaUrl != null || imageUrl != null;
  bool get isReply => replyToId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderId == other.senderId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => id.hashCode ^ senderId.hashCode ^ timestamp.hashCode;

  @override
  String toString() =>
      'ChatMessage(id: $id, sender: $senderName, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}...)';

  // Static helper methods for parsing
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    return DateTime.now();
  }

  static MessageContext _parseContext(String? context) {
    if (context == null) return MessageContext.direct;
    switch (context.toLowerCase()) {
      case 'room':
      case 'voice':
      case 'video':
        return MessageContext.room;
      case 'group':
        return MessageContext.group;
      case 'speeddating':
      case 'speed_dating':
        return MessageContext.speedDating;
      case 'direct':
      case 'dm':
      default:
        return MessageContext.direct;
    }
  }

  static MessageContentType _parseContentType(String? type) {
    if (type == null) return MessageContentType.text;
    switch (type.toLowerCase()) {
      case 'image':
        return MessageContentType.image;
      case 'video':
        return MessageContentType.video;
      case 'audio':
        return MessageContentType.audio;
      case 'system':
        return MessageContentType.system;
      case 'emote':
        return MessageContentType.emote;
      case 'sticker':
        return MessageContentType.sticker;
      case 'file':
        return MessageContentType.file;
      case 'text':
      default:
        return MessageContentType.text;
    }
  }

  static MessageStatus _parseStatus(String? status) {
    if (status == null) return MessageStatus.sent;
    switch (status.toLowerCase()) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }

  /// Create a deterministic conversation ID from two user IDs
  /// The IDs are sorted to ensure the same ID regardless of order
  static String createConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}

class PinnedMessage {
  final String id;
  final String messageId;
  final String roomId;
  final String pinnedBy;
  final DateTime pinnedAt;
  final ChatMessage message;

  PinnedMessage({
    required this.id,
    required this.messageId,
    required this.roomId,
    required this.pinnedBy,
    required this.pinnedAt,
    required this.message,
  });

  factory PinnedMessage.fromMap(Map<String, dynamic> map, ChatMessage message) {
    return PinnedMessage(
      id: map['id'] as String,
      messageId: map['messageId'] as String,
      roomId: map['roomId'] as String,
      pinnedBy: map['pinnedBy'] as String,
      pinnedAt: (map['pinnedAt'] as Timestamp).toDate(),
      message: message,
    );
  }
}

class ChatSettings {
  final String roomId;
  final bool slowMode;
  final int slowModeDuration;
  final bool allowMedia;
  final bool filterProfanity;

  ChatSettings({
    required this.roomId,
    required this.slowMode,
    required this.slowModeDuration,
    required this.allowMedia,
    required this.filterProfanity,
  });

  factory ChatSettings.fromMap(Map<String, dynamic> map) {
    return ChatSettings(
      roomId: map['roomId'] as String,
      slowMode: map['slowMode'] as bool? ?? false,
      slowModeDuration: map['slowModeDuration'] as int? ?? 5,
      allowMedia: map['allowMedia'] as bool? ?? true,
      filterProfanity: map['filterProfanity'] as bool? ?? false,
    );
  }
}
