// lib/models/room_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'participant_model.dart';

class RoomModel {
  final String roomId;
  final String hostId;
  final String title;
  final String topic;
  final DateTime createdAt;
  final bool isLocked;
  final Map<String, ParticipantModel> participants;

  RoomModel({
    required this.roomId,
    required this.hostId,
    required this.title,
    required this.topic,
    required this.createdAt,
    required this.isLocked,
    required this.participants,
  });

  factory RoomModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final participantsMap =
        (data['participants'] as Map<String, dynamic>? ?? {})
            .map((uid, p) => MapEntry(uid, ParticipantModel.fromMap(uid, p)));
    return RoomModel(
      roomId: doc.id,
      hostId: data['hostId'] ?? '',
      title: data['title'] ?? '',
      topic: data['topic'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLocked: data['isLocked'] ?? false,
      participants: participantsMap,
    );
  }
}
