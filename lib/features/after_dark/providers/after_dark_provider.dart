import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/room/contracts/room_visibility_contract.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/services/room_service.dart';
import '../../auth/controllers/auth_controller.dart';

const _kEnabled = 'after_dark_enabled';
const _kPinStored = 'after_dark_pin';
const _kDobYes = 'after_dark_dob_confirmed';

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
      return ref
          .watch(roomServiceProvider)
          .watchRoomsWithVisibility(
            category: category,
            limit: 50,
            includeAdultRooms: true,
          )
          .map((classifiedRooms) {
        final rooms = classifiedRooms
            .where((item) => item.tier != RoomVisibilityTier.invalid)
            .map((item) => item.room)
            .where((room) => room.isAdult)
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
    final uid = _ref.read(authControllerProvider).uid ?? 'anonymous';
    await prefs.setString(_kPinStored, _hashPin(pin, uid));
    // SINGLE SOURCE OF TRUTH FOR ADULT CONSENT STATE:
    // Adult mode consent flags (adultModeEnabled, adultConsentAccepted,
    // adultModeEnabledAt) live ONLY in preferences/{uid}. They are merged into
    // the user model by ProfileService.loadProfile() so that userProvider
    // surfaces them correctly. Do NOT write these fields to users/{uid} or
    // adult_profile/details — those collections have different purposes:
    //   preferences/{uid}          → consent/toggle state  (this file)
    //   adult_profile/details      → structured profile data (bio, intents, etc.)
    // Fields (username, email, photoUrl, etc.) and would reject adultModeEnabled.
    final firestoreUid = _ref.read(authControllerProvider).uid;
    if (firestoreUid != null) {
      await _ref
          .read(firestoreProvider)
          .collection('preferences')
          .doc(firestoreUid)
          .set({
            'userId': firestoreUid,
            'adultModeEnabled': true,
            'adultConsentAccepted': true,
            'adultModeEnabledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
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
    final uid = _ref.read(authControllerProvider).uid ?? 'anonymous';
    final valid = _hashPin(pin, uid) == stored;
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
      await _ref
          .read(firestoreProvider)
          .collection('preferences')
          .doc(uid)
          .set({
            'userId': uid,
            'adultModeEnabled': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }
    _ref.invalidate(afterDarkEnabledProvider);
    _ref.read(afterDarkSessionProvider.notifier).state = false;
  }

  // ── SHA-256 PIN hash with per-user salt ─────────────────────────────────
  // Using the user UID as salt ensures PINs cannot be pre-computed across
  // users even if SharedPreferences is extracted from the device.
  static String _hashPin(String pin, String uid) {
    final saltedInput = utf8.encode('$uid:mx_afterdark:$pin');
    final digest = sha256.convert(saltedInput);
    return digest.toString();
  }
}
