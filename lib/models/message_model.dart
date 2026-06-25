import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, system }

class Message {
  final String roomId;
  final String senderId;
  final String text;
  final MessageType type;
  final Timestamp createdAt;

  Message({
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.type,
    required this.createdAt,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      roomId: data['roomId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type'] ?? 'text'}',
        orElse: () => MessageType.text,
      ),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'senderId': senderId,
      'text': text,
      'type': type.toString().split('.').last,
      'createdAt': createdAt,
    };
  }
}
