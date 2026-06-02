import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/referral_model.dart';

class ReferralService {
  ReferralService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  bool _asBool(dynamic value, {bool fallback = true}) {
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

  Future<String> generateReferralCode(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId is required');
    }

    final result = await _functions
        .httpsCallable('generateReferralCode')
        .call<Map<String, dynamic>>(<String, dynamic>{'userId': userId});
    final data = Map<String, dynamic>.from(result.data);
    final code = _asString(data['code']);
    if (code.isEmpty) {
      throw Exception('Could not generate referral code. Please retry.');
    }
    return code;
  }

  Future<bool> redeemReferral(String code, String userId) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty || userId.trim().isEmpty) {
      return false;
    }

    final result = await _functions
        .httpsCallable('redeemReferralCode')
        .call<Map<String, dynamic>>(<String, dynamic>{
      'code': normalizedCode,
      'userId': userId,
    });
    final data = Map<String, dynamic>.from(result.data);
    return _asBool(data['redeemed'], fallback: false);
  }

  Stream<String?> referralCodeStream(String userId) {
    if (userId.trim().isEmpty) {
      return Stream<String?>.value(null);
    }

    return _firestore
        .collection('referral_codes')
        .where('ownerUserId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty ? null : snapshot.docs.first.id,
        );
  }

  Stream<double> referralEarningsTotalStream(String userId) {
    if (userId.trim().isEmpty) {
      return Stream<double>.value(0);
    }

    return _firestore
        .collection('referral_earnings')
        .where('beneficiaryUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      var total = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        total += (data['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    });
  }

  Stream<List<ReferralAttributionModel>> referralsForUserStream(String userId) {
    if (userId.trim().isEmpty) {
      return Stream<List<ReferralAttributionModel>>.value(
        <ReferralAttributionModel>[],
      );
    }

    return _firestore
        .collection('referrals')
        .where('referrerUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ReferralAttributionModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }),
              )
              .toList(growable: false),
        );
  }
}
