import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileGateService {
  ProfileGateService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  static bool _looksAnonymous(String value) {
    final normalized = value.trim();
    final generatedHandlePattern = RegExp(
      r'^(User|Guest|Member) [A-Z0-9]{1,4}$',
    );
    final opaqueIdPattern = RegExp(r'^[A-Za-z0-9_-]{20,}$');
    return normalized.isEmpty ||
        normalized == 'MixVy User' ||
        normalized == 'MixVy Member' ||
        generatedHandlePattern.hasMatch(normalized) ||
        opaqueIdPattern.hasMatch(normalized);
  }

  static Future<bool> isProfileComplete(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;

      final data = doc.data() ?? <String, dynamic>{};
      final explicitComplete = data['isComplete'];
      if (explicitComplete is bool) {
        return explicitComplete;
      }

      final username = _asString(data['username']);
      final displayName = _asString(data['displayName'], fallback: username);
      return username.isNotEmpty &&
          displayName.isNotEmpty &&
          !_looksAnonymous(username) &&
          !_looksAnonymous(displayName);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to evaluate profile completeness for $uid',
        name: 'ProfileGateService',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
  }
}
