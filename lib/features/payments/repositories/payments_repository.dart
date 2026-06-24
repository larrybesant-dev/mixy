// lib/features/payments/repositories/payments_repository.dart
//
// Firestore implementation of IPaymentsRepository.
// Coin debit/credit uses Firestore transactions to guarantee atomicity.
// UID validation is enforced before every write — never in the UI.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/coin_transaction.dart';
import 'i_payments_repository.dart';

class PaymentsRepository implements IPaymentsRepository {
  final FirebaseFirestore _db;

  PaymentsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _wallet(String uid) =>
      _db.collection('wallets').doc(uid);

  CollectionReference<Map<String, dynamic>> _txns(String uid) =>
      _db.collection('wallets').doc(uid).collection('transactions');

  @override
  Future<int> getCoinBalance(String uid) async {
    _assertUid(uid);
    final doc = await _wallet(uid).get();
    return (doc.data()?['coins'] as num?)?.toInt() ?? 0;
  }

  @override
  Stream<int> watchCoinBalance(String uid) {
    _assertUid(uid);
    return _wallet(uid)
        .snapshots()
        .map((d) => (d.data()?['coins'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<void> creditCoins({
    required String uid,
    required int amount,
    required String transactionId,
    required String source,
  }) async {
    _assertUid(uid);
    if (amount <= 0) throw ArgumentError('Credit amount must be positive');
    await _db.runTransaction((txn) async {
      final walletRef = _wallet(uid);
      final walletDoc = await txn.get(walletRef);
      final current = (walletDoc.data()?['coins'] as num?)?.toInt() ?? 0;
      txn.set(walletRef, {'coins': current + amount}, SetOptions(merge: true));
      txn.set(_txns(uid).doc(transactionId), {
        'id': transactionId,
        'userId': uid,
        'amount': amount,
        'type': 'purchase',
        'description': 'Credit: $source',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> debitCoins({
    required String uid,
    required int amount,
    required String reason,
  }) async {
    _assertUid(uid);
    if (amount <= 0) throw ArgumentError('Debit amount must be positive');
    await _db.runTransaction((txn) async {
      final walletRef = _wallet(uid);
      final walletDoc = await txn.get(walletRef);
      final current = (walletDoc.data()?['coins'] as num?)?.toInt() ?? 0;
      if (current < amount) throw Exception('Insufficient coin balance');
      txn.update(walletRef, {'coins': current - amount});
      txn.set(_txns(uid).doc(), {
        'userId': uid,
        'amount': -amount,
        'type': 'penalty',
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> transferCoins({
    required String fromUid,
    required String toUid,
    required int amount,
    required String reason,
  }) async {
    _assertUid(fromUid);
    _assertUid(toUid);
    if (fromUid == toUid) throw ArgumentError('Cannot transfer to self');
    if (amount <= 0) throw ArgumentError('Transfer amount must be positive');

    await _db.runTransaction((txn) async {
      final fromRef = _wallet(fromUid);
      final toRef = _wallet(toUid);
      final fromDoc = await txn.get(fromRef);
      final toDoc = await txn.get(toRef);

      final fromBal = (fromDoc.data()?['coins'] as num?)?.toInt() ?? 0;
      final toBal = (toDoc.data()?['coins'] as num?)?.toInt() ?? 0;

      if (fromBal < amount) throw Exception('Insufficient coin balance');

      txn.update(fromRef, {'coins': fromBal - amount});
      txn.set(toRef, {'coins': toBal + amount}, SetOptions(merge: true));

      final now = FieldValue.serverTimestamp();
      txn.set(_txns(fromUid).doc(), {
        'userId': fromUid,
        'amount': -amount,
        'type': 'gift',
        'relatedUserId': toUid,
        'description': reason,
        'timestamp': now,
      });
      txn.set(_txns(toUid).doc(), {
        'userId': toUid,
        'amount': amount,
        'type': 'gift',
        'relatedUserId': fromUid,
        'description': reason,
        'timestamp': now,
      });
    });
  }

  @override
  Future<List<CoinTransaction>> getTransactionHistory(
    String uid, {
    int limit = 30,
    String? afterTransactionId,
  }) async {
    _assertUid(uid);
    Query<Map<String, dynamic>> query =
        _txns(uid).orderBy('timestamp', descending: true).limit(limit);

    if (afterTransactionId != null) {
      final pivot = await _txns(uid).doc(afterTransactionId).get();
      if (pivot.exists) query = query.startAfterDocument(pivot);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => CoinTransaction.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  void _assertUid(String uid) {
    if (uid.trim().isEmpty) throw ArgumentError('UID must not be empty');
  }
}

final paymentsRepositoryProvider = Provider<IPaymentsRepository>(
  (ref) => PaymentsRepository(),
);

