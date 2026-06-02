import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/mixvy_economy_config.dart';
import '../models/cash_out_request_model.dart';

final cashOutServiceProvider = Provider<CashOutService>(
  (ref) => CashOutService(),
);

class CashOutService {
  CashOutService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<List<CashOutRequestModel>> requestsForCurrentUser() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return const Stream<List<CashOutRequestModel>>.empty();
    }

    return _firestore
        .collection('cash_out_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map(
            (doc) => CashOutRequestModel.fromJson(doc.id, doc.data()),
          )
          .toList(growable: false)
        ..sort(
          (a, b) =>
              (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      return requests;
    });
  }

  Future<void> requestCashOut(double amount) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not logged in');
    }

    if (amount < MixVyEconomyConfig.creatorPayoutMinimumCash) {
      throw Exception(
        'Minimum cash-out is ${MixVyEconomyConfig.creatorPayoutMinimumCash.toStringAsFixed(2)}.',
      );
    }

    // Local Validation Hardening: Check available balance before calling function.
    // This prevents unnecessary Cloud Function invocations and provides
    // immediate feedback.
    final walletDoc = await _firestore.collection('wallets').doc(userId).get();
    final balance =
        (walletDoc.data()?['cashBalance'] as num?)?.toDouble() ?? 0.0;

    // Also account for other pending requests that haven't been deducted yet.
    final pendingSnapshot = await _firestore
        .collection('cash_out_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    double pendingTotal = 0.0;
    for (final doc in pendingSnapshot.docs) {
      pendingTotal += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    if (amount > (balance - pendingTotal)) {
      throw Exception(
        'Requested amount ($amount) exceeds available balance '
        '(${(balance - pendingTotal).toStringAsFixed(2)}).',
      );
    }

    // Hardening: Optimistically create the pending request record.
    // The Cloud Function will process this and update status/balances.
    await _firestore.collection('cash_out_requests').add({
      'userId': userId,
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final callable = _functions.httpsCallable('requestCashOut');
    await callable.call<Map<String, dynamic>>({'amount': amount});
  }
}
