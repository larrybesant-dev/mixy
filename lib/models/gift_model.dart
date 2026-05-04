class GiftModel {
  final String? id;
  final String? senderId;
  final String? receiverId;
  final int? amount;
  final String? type;
  final DateTime? sentAt;

  GiftModel({
    this.id,
    this.senderId,
    this.receiverId,
    this.amount,
    this.type,
    this.sentAt,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) => GiftModel(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    amount: json['amount'],
    type: json['type'],
    sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'amount': amount,
    'type': type,
    'sentAt': sentAt?.toIso8601String(),
  };
}
