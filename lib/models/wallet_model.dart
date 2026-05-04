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

String? _asNullableString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

class WalletModel {
  const WalletModel({
    required this.userId,
    this.coinBalance = 0,
    this.cashBalance = 0,
    this.referralEarnings = 0,
    this.roomEarnings = 0,
    this.giftEarnings = 0,
    this.pendingCashOut = 0,
    this.updatedAt,
  });

  final String userId;
  final int coinBalance;
  final double cashBalance;
  final double referralEarnings;
  final double roomEarnings;
  final double giftEarnings;
  final double pendingCashOut;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'coinBalance': coinBalance,
      'cashBalance': cashBalance,
      'referralEarnings': referralEarnings,
      'roomEarnings': roomEarnings,
      'giftEarnings': giftEarnings,
      'pendingCashOut': pendingCashOut,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      userId: _asString(json['userId']),
      coinBalance:
          ((json['balance'] ?? json['coinBalance'] ?? json['userCoinBalance'])
                  as num?)
              ?.toInt() ??
          0,
      cashBalance: (json['cashBalance'] as num?)?.toDouble() ?? 0,
      referralEarnings: (json['referralEarnings'] as num?)?.toDouble() ?? 0,
      roomEarnings: (json['roomEarnings'] as num?)?.toDouble() ?? 0,
      giftEarnings: (json['giftEarnings'] as num?)?.toDouble() ?? 0,
      pendingCashOut: (json['pendingCashOut'] as num?)?.toDouble() ?? 0,
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }
}

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    this.referenceId,
    this.metadata = const <String, dynamic>{},
    this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final String? referenceId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'status': status,
      'referenceId': referenceId,
      'metadata': metadata,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return WalletLedgerEntry(
      id: _asString(json['id']),
      userId: _asString(json['userId']),
      type: _asString(json['type'], fallback: 'unknown'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: _asString(json['currency'], fallback: 'usd'),
      status: _asString(json['status'], fallback: 'pending'),
      referenceId: _asNullableString(json['referenceId']),
      metadata: Map<String, dynamic>.from(
        json['metadata'] ?? const <String, dynamic>{},
      ),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  return DateTime.tryParse(value.toString());
}
