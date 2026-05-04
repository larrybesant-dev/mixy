class CoinTransactionModel {
  final String? id;
  final String? userId;
  final int? amount;
  final String? type;
  final DateTime? createdAt;

  CoinTransactionModel({
    this.id,
    this.userId,
    this.amount,
    this.type,
    this.createdAt,
  });

  factory CoinTransactionModel.fromJson(Map<String, dynamic> json) =>
      CoinTransactionModel(
        id: json['id'],
        userId: json['userId'],
        amount: json['amount'],
        type: json['type'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'amount': amount,
    'type': type,
    'createdAt': createdAt?.toIso8601String(),
  };
}
