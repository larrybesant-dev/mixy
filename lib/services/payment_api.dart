import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

String _asTrimmedString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
  if (value == null) {
    return fallback;
  }
  final normalized = value.toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

bool _asBool(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

DateTime _asDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

abstract class PaymentFunctionsGateway {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> payload);
}

class FirebasePaymentFunctionsGateway implements PaymentFunctionsGateway {
  FirebasePaymentFunctionsGateway({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable(name);
    final result = await callable.call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(result.data);
  }
}

abstract class PaymentAuthGateway {
  User? get currentUser;
}

class FirebasePaymentAuthGateway implements PaymentAuthGateway {
  FirebasePaymentAuthGateway({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  User? get currentUser => _auth.currentUser;
}

class CoinTransaction {
  final String id;
  final String senderId;
  final String receiverId;
  final double amount;
  final DateTime timestamp;
  final String status; // sent, requested, completed

  CoinTransaction({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
  };

  factory CoinTransaction.fromJson(Map<String, dynamic> json) =>
      CoinTransaction(
        id: _asTrimmedString(json['id']),
        senderId: _asTrimmedString(json['senderId']),
        receiverId: _asTrimmedString(json['receiverId']),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        timestamp: _asDateTime(json['timestamp']),
        status: _asTrimmedString(json['status'], fallback: 'pending'),
      );
}

class RefundRequest {
  final String id;
  final String transactionId;
  final String requesterId;
  final double amount;
  final String status;
  final String reason;
  final DateTime? createdAt;

  const RefundRequest({
    required this.id,
    required this.transactionId,
    required this.requesterId,
    required this.amount,
    required this.status,
    required this.reason,
    required this.createdAt,
  });

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }

    return RefundRequest(
      id: _asTrimmedString(json['id']),
      transactionId: _asTrimmedString(json['transactionId']),
      requesterId: _asTrimmedString(json['requesterId']),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: _asTrimmedString(json['status'], fallback: 'pending'),
      reason: _asTrimmedString(json['reason']),
      createdAt: createdAt,
    );
  }
}

class StripeConnectStatus {
  const StripeConnectStatus({
    required this.hasAccount,
    required this.chargesEnabled,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
    required this.onboardingComplete,
    this.accountId,
    this.country,
  });

  final bool hasAccount;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final bool onboardingComplete;
  final String? accountId;
  final String? country;

  factory StripeConnectStatus.fromJson(Map<String, dynamic> json) {
    return StripeConnectStatus(
      hasAccount: _asBool(
        json['hasAccount'],
        fallback: _asTrimmedString(json['accountId']).isNotEmpty,
      ),
      chargesEnabled: _asBool(json['chargesEnabled'], fallback: false),
      payoutsEnabled: _asBool(json['payoutsEnabled'], fallback: false),
      detailsSubmitted: _asBool(json['detailsSubmitted'], fallback: false),
      onboardingComplete: _asBool(json['onboardingComplete'], fallback: false),
      accountId: _asTrimmedString(json['accountId']).isEmpty
          ? null
          : _asTrimmedString(json['accountId']),
      country: _asTrimmedString(json['country']).isEmpty
          ? null
          : _asTrimmedString(json['country']),
    );
  }
}

class PaymentIntentResult {
  const PaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.idempotencyKey,
  });

  final String clientSecret;
  final String paymentIntentId;
  final String idempotencyKey;
}

class PaymentApi {
  static final _firestore = FirebaseFirestore.instance;
  static const _uuid = Uuid();
  static PaymentFunctionsGateway? _functionsGateway;
  static PaymentAuthGateway? _authGateway;

  static PaymentFunctionsGateway get _resolvedFunctionsGateway =>
      _functionsGateway ??= FirebasePaymentFunctionsGateway();

  static PaymentAuthGateway get _resolvedAuthGateway =>
      _authGateway ??= FirebasePaymentAuthGateway();

  @visibleForTesting
  static void configureForTesting({
    PaymentFunctionsGateway? functionsGateway,
    PaymentAuthGateway? authGateway,
  }) {
    if (functionsGateway != null) {
      _functionsGateway = functionsGateway;
    }
    if (authGateway != null) {
      _authGateway = authGateway;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _functionsGateway = null;
    _authGateway = null;
  }

  static Future<T> _callFunction<T>(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final result = await _resolvedFunctionsGateway.call(name, payload);
    return result as T;
  }

  /// Creates a payment intent by calling a backend endpoint that integrates with Stripe
  static Future<PaymentIntentResult> createIntent({
    required double amount,
    required String currency,
    required String recipientId,
    String? idempotencyKey,
  }) async {
    final resolvedIdempotencyKey =
        (idempotencyKey == null || idempotencyKey.trim().isEmpty)
        ? 'intent_${_uuid.v4()}'
        : idempotencyKey.trim();

    final data =
        await _callFunction<Map<String, dynamic>>('createPaymentIntent', {
          'amount': amount,
          'currency': currency,
          'recipientId': recipientId,
          'idempotencyKey': resolvedIdempotencyKey,
        });
    final clientSecret = _asTrimmedString(data['clientSecret']);
    final paymentIntentId = _asTrimmedString(data['paymentIntentId']);
    final returnedIdempotencyKey = _asTrimmedString(
      data['idempotencyKey'],
      fallback: resolvedIdempotencyKey,
    );
    if (clientSecret.isEmpty) {
      throw Exception('clientSecret missing in response');
    }
    if (paymentIntentId.isEmpty) {
      throw Exception('paymentIntentId missing in response');
    }
    return PaymentIntentResult(
      clientSecret: clientSecret,
      paymentIntentId: paymentIntentId,
      idempotencyKey: returnedIdempotencyKey,
    );
  }

  /// Notifies backend of successful payment (records transaction in Firestore)
  static Future<void> notifySuccess({
    required String recipientId,
    required double amount,
    required String paymentIntentId,
    String? idempotencyKey,
  }) async {
    final user = _resolvedAuthGateway.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    await _callFunction<Map<String, dynamic>>('recordStripePaymentSuccess', {
      'recipientId': recipientId,
      'amount': amount,
      'paymentIntentId': paymentIntentId,
      'idempotencyKey': idempotencyKey,
    });
  }

  static Future<void> sendPayment(
    String receiverId,
    double amount, {
    String? idempotencyKey,
  }) async {
    final user = _resolvedAuthGateway.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    await _callFunction<Map<String, dynamic>>('sendCoinTransfer', {
      'receiverId': receiverId,
      'amount': amount,
      'idempotencyKey': idempotencyKey ?? 'send_${_uuid.v4()}',
    });
  }

  static Future<void> requestPayment(
    String requesterId,
    String targetId,
    double amount, {
    String? idempotencyKey,
  }) async {
    final user = _resolvedAuthGateway.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    if (user.uid != requesterId) {
      throw Exception('Authenticated user does not match requesterId');
    }
    await _callFunction<Map<String, dynamic>>('requestCoinTransfer', {
      'targetId': targetId,
      'amount': amount,
      'idempotencyKey': idempotencyKey ?? 'request_${_uuid.v4()}',
    });
  }

  static Future<StripeConnectStatus> getStripeConnectStatus() async {
    final user = _resolvedAuthGateway.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final data = await _callFunction<Map<String, dynamic>>(
      'getStripeConnectStatus',
      {},
    );
    return StripeConnectStatus.fromJson(data);
  }

  static Future<String> createStripeConnectOnboardingLink() async {
    final user = _resolvedAuthGateway.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final data = await _callFunction<Map<String, dynamic>>(
      'createStripeConnectOnboardingLink',
      {},
    );
    final url = _asTrimmedString(data['url']);
    if (url.isEmpty) {
      throw Exception('Onboarding URL missing in response');
    }
    return url;
  }

  static Future<String> createStripeConnectDashboardLink() async {
    final user = _resolvedAuthGateway.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final data = await _callFunction<Map<String, dynamic>>(
      'createStripeConnectDashboardLink',
      {},
    );
    final url = _asTrimmedString(data['url']);
    if (url.isEmpty) {
      throw Exception('Dashboard URL missing in response');
    }
    return url;
  }

  static Future<void> requestRefund({
    required String transactionId,
    required String reason,
  }) async {
    final user = _resolvedAuthGateway.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    final normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty) {
      throw Exception('Transaction id is required');
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.length < 10) {
      throw Exception('Refund reason must be at least 10 characters.');
    }

    await _callFunction<Map<String, dynamic>>('requestRefund', {
      'transactionId': normalizedTransactionId,
      'reason': normalizedReason,
    });
  }

  static Stream<List<RefundRequest>> getMyRefundRequests(String userId) {
    if (userId.trim().isEmpty) {
      return const Stream<List<RefundRequest>>.empty();
    }

    return _firestore
        .collection('refund_requests')
        .where('requesterId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final requests =
              snapshot.docs
                  .map((doc) => RefundRequest.fromJson(doc.data()))
                  .toList(growable: false)
                ..sort((a, b) {
                  final aTime =
                      a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });
          return requests;
        });
  }

  static Stream<List<CoinTransaction>> getTransactions(String userId) {
    if (userId.trim().isEmpty) {
      return const Stream<List<CoinTransaction>>.empty();
    }

    return _firestore
        .collection('transactions')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final transactions =
              snapshot.docs
                  .map((doc) => CoinTransaction.fromJson(doc.data()))
                  .toList(growable: false)
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return transactions;
        });
  }
}



