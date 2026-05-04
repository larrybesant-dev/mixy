String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

class ReferralCodeModel {
  const ReferralCodeModel({
    required this.code,
    required this.ownerUserId,
    this.isActive = true,
    this.createdAt,
  });

  final String code;
  final String ownerUserId;
  final bool isActive;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'ownerUserId': ownerUserId,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ReferralCodeModel.fromJson(Map<String, dynamic> json) {
    return ReferralCodeModel(
      code: _asString(json['code']),
      ownerUserId: _asString(json['ownerUserId']),
      isActive: _asBool(json['isActive'], fallback: true),
      createdAt: _parseNullableDate(json['createdAt']),
    );
  }
}

class ReferralAttributionModel {
  const ReferralAttributionModel({
    required this.id,
    required this.referrerUserId,
    required this.referredUserId,
    required this.referralCode,
    this.subscriptionStatus = 'pending',
    this.rewardStatus = 'pending',
    this.createdAt,
    this.conversionAt,
  });

  final String id;
  final String referrerUserId;
  final String referredUserId;
  final String referralCode;
  final String subscriptionStatus;
  final String rewardStatus;
  final DateTime? createdAt;
  final DateTime? conversionAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referrerUserId': referrerUserId,
      'referredUserId': referredUserId,
      'referralCode': referralCode,
      'subscriptionStatus': subscriptionStatus,
      'rewardStatus': rewardStatus,
      'createdAt': createdAt?.toIso8601String(),
      'conversionAt': conversionAt?.toIso8601String(),
      'participantIds': [referrerUserId, referredUserId],
    };
  }

  factory ReferralAttributionModel.fromJson(Map<String, dynamic> json) {
    return ReferralAttributionModel(
      id: _asString(json['id']),
      referrerUserId: _asString(json['referrerUserId']),
      referredUserId: _asString(json['referredUserId']),
      referralCode: _asString(json['referralCode']),
      subscriptionStatus: _asString(
        json['subscriptionStatus'],
        fallback: 'pending',
      ),
      rewardStatus: _asString(json['rewardStatus'], fallback: 'pending'),
      createdAt: _parseNullableDate(json['createdAt']),
      conversionAt: _parseNullableDate(json['conversionAt']),
    );
  }
}

class ReferralEarningModel {
  const ReferralEarningModel({
    required this.id,
    required this.referralId,
    required this.beneficiaryUserId,
    required this.sourceUserId,
    required this.amount,
    this.currency = 'usd',
    this.status = 'pending',
    this.createdAt,
  });

  final String id;
  final String referralId;
  final String beneficiaryUserId;
  final String sourceUserId;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referralId': referralId,
      'beneficiaryUserId': beneficiaryUserId,
      'sourceUserId': sourceUserId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ReferralEarningModel.fromJson(Map<String, dynamic> json) {
    return ReferralEarningModel(
      id: _asString(json['id']),
      referralId: _asString(json['referralId']),
      beneficiaryUserId: _asString(json['beneficiaryUserId']),
      sourceUserId: _asString(json['sourceUserId']),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: _asString(json['currency'], fallback: 'usd'),
      status: _asString(json['status'], fallback: 'pending'),
      createdAt: _parseNullableDate(json['createdAt']),
    );
  }
}
