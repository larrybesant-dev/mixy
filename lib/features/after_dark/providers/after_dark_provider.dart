import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/models/room_model.dart';
import '../../auth/controllers/auth_controller.dart';

const _kEnabled   = 'after_dark_enabled';
const _kPinStored = 'after_dark_pin';
const _kDobYes    = 'after_dark_dob_confirmed';

// ── Session state — cleared when app is closed ───────────────────────────────
final afterDarkSessionProvider = StateProvider<bool>((ref) => false);

// ── Persistent enable flag — reads from SharedPreferences ────────────────────
final afterDarkEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kEnabled) ?? false;
});

// ── Controller ────────────────────────────────────────────────────────────────
final afterDarkControllerProvider = Provider<AfterDarkController>((ref) {
  return AfterDarkController(ref);
});

final adultRoomsProvider = StreamProvider.autoDispose
    .family<List<RoomModel>, String?>((ref, category) {
      Query<Map<String, dynamic>> query = ref
          .watch(firestoreProvider)
          .collection('rooms')
          .where('isLive', isEqualTo: true)
          .where('isAdult', isEqualTo: true)
          .limit(50);

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      return query.snapshots().map((snapshot) {
        final rooms = snapshot.docs
            .map((doc) => RoomModel.fromJson(doc.data(), doc.id))
            .toList(growable: false);
        rooms.sort((a, b) {
          final aTs = a.createdAt?.seconds ?? 0;
          final bTs = b.createdAt?.seconds ?? 0;
          final byCreatedAt = bTs.compareTo(aTs);
          if (byCreatedAt != 0) {
            return byCreatedAt;
          }
          return a.id.compareTo(b.id);
        });
        return rooms;
      });
    });

class AfterDarkController {
  AfterDarkController(this._ref);
  final Ref _ref;

  // ── Activation (called after age gate + PIN setup) ────────────────────────
  Future<void> enable(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    await prefs.setBool(_kDobYes, true);
    await prefs.setString(_kPinStored, _obfuscate(pin));
    // Persist consent on Firestore user doc
    final uid = _ref.read(authControllerProvider).uid;
    if (uid != null) {
      await _ref.read(firestoreProvider).collection('users').doc(uid).set({
        'adultModeEnabled': true,
        'adultConsentAccepted': true,
        'adultModeEnabledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _ref.invalidate(afterDarkEnabledProvider);
    _ref.read(afterDarkSessionProvider.notifier).state = true;
  }

  // ── Verify PIN → activate session ─────────────────────────────────────────
  Future<bool> unlock(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kPinStored);
    if (stored == null) return false;
    final valid = _obfuscate(pin) == stored;
    if (valid) {
      _ref.read(afterDarkSessionProvider.notifier).state = true;
    }
    return valid;
  }

  // ── Lock session (stays enabled but requires PIN again) ───────────────────
  void lock() {
    _ref.read(afterDarkSessionProvider.notifier).state = false;
  }

  // ── Full disable ──────────────────────────────────────────────────────────
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEnabled);
    await prefs.remove(_kPinStored);
    await prefs.remove(_kDobYes);
    final uid = _ref.read(authControllerProvider).uid;
    if (uid != null) {
      await _ref.read(firestoreProvider).collection('users').doc(uid).set({
        'adultModeEnabled': false,
      }, SetOptions(merge: true));
    }
    _ref.invalidate(afterDarkEnabledProvider);
    _ref.read(afterDarkSessionProvider.notifier).state = false;
  }

  // ── Simple obfuscation (prevents plain-text PIN in prefs) ────────────────
  static String _obfuscate(String pin) {
    const salt = 'mx_afterdark_2026';
    final bytes = utf8.encode(pin + salt);
    return base64Url.encode(bytes);
  }
}
