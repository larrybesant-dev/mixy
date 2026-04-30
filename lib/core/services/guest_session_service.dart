import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight guest-browse session.
///
/// Does NOT use Firebase anonymous auth — the auth controller explicitly
/// rejects anonymous sessions.  Instead this is a local flag that tells the
/// routing layer to permit read-only browsing without an account.
///
/// The flag is cleared automatically when the user successfully signs in
/// (call [clearGuestSession]) and on explicit sign-out.
abstract final class GuestSessionService {
  static const _prefsKey = 'mixvy_guest_session_active';

  /// In-memory cache so synchronous reads are cheap after first load.
  static bool _active = false;

  // ─── Initialisation ────────────────────────────────────────────────────────

  /// Call once at app start (after [WidgetsFlutterBinding.ensureInitialized])
  /// to restore a persisted guest session.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _active = prefs.getBool(_prefsKey) ?? false;
  }

  // ─── State access ──────────────────────────────────────────────────────────

  /// `true` while the user is browsing as a guest (no Firebase UID).
  static bool get isActive => _active;

  // ─── Mutations ─────────────────────────────────────────────────────────────

  /// Enter guest-browse mode.  Persists across hot-restarts.
  static Future<void> enterAsGuest() async {
    _active = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  /// Clear the guest session — call this when the user signs in or signs up.
  static Future<void> clearGuestSession() async {
    _active = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
