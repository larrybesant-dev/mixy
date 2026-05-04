import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/mixvy_economy_config.dart';
import '../models/cash_out_request_model.dart';

final cashOutServiceProvider = Provider<CashOutService>(
  (ref) => CashOutService(),
);

class CashOutService {
  CashOutService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
          final requests =
              snapshot.docs
                  .map(
                    (doc) => CashOutRequestModel.fromJson(doc.id, doc.data()),
                  )
                  .toList(growable: false)
                ..sort(
                  (a, b) =>
                      (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(
                            a.createdAt ??
                                DateTime.fromMillisecondsSinceEpoch(0),
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

    final walletSnapshot = await _firestore
        .collection('wallets')
        .doc(userId)
        .get();
    final walletData = walletSnapshot.data() ?? const <String, dynamic>{};
    final cashBalance = (walletData['cashBalance'] as num?)?.toDouble() ?? 0;

    final requestsSnapshot = await _firestore
        .collection('cash_out_requests')
        .where('userId', isEqualTo: userId)
        .get();
    final pendingTotal = requestsSnapshot.docs
        .map((doc) => CashOutRequestModel.fromJson(doc.id, doc.data()))
        .where(
          (request) =>
              request.status == 'pending' || request.status == 'processing',
        )
        .fold<double>(
          0,
          (runningTotal, request) => runningTotal + request.amount,
        );

    final availableToCashOut = cashBalance - pendingTotal;
    if (amount > availableToCashOut) {
      throw Exception('Requested amount exceeds available cash balance.');
    }

    await _firestore.collection('cash_out_requests').add({
      'userId': userId,
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
