class RoomSlotModel {
  final String slotId;
  final String? userId;

  const RoomSlotModel({required this.slotId, this.userId});

  bool get isAvailable => (userId ?? '').isEmpty;

  factory RoomSlotModel.fromMap(String slotId, Map<String, dynamic>? data) {
    final rawUserId = data?['userId'];
    final parsedUserId = (rawUserId is String && rawUserId.isNotEmpty)
        ? rawUserId
        : null;
    return RoomSlotModel(slotId: slotId, userId: parsedUserId);
  }

  Map<String, dynamic> toMap() => {'userId': userId};

  RoomSlotModel copyWith({String? slotId, String? userId}) {
    return RoomSlotModel(
      slotId: slotId ?? this.slotId,
      userId: userId ?? this.userId,
    );
  }
}
