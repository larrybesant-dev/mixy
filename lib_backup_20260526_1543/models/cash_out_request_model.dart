import 'package:cloud_firestore/cloud_firestore.dart';

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

class CashOutRequestModel {
  const CashOutRequestModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String userId;
  final double amount;
  final String status;
  final DateTime? createdAt;

  factory CashOutRequestModel.fromJson(String id, Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return CashOutRequestModel(
      id: id,
      userId: _asString(json['userId']),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: _asString(json['status'], fallback: 'pending'),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.tryParse(createdAt?.toString() ?? ''),
    );
  }
}
