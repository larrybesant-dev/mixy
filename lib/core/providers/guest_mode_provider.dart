import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/services/guest_session_service.dart';

/// Reactive guest-browse mode flag.
///
/// Set to `true` when the user taps "ENTER AS GUEST".
/// Automatically reverts to `false` once a real Firebase account signs in
/// (handled in [_RouterRefreshNotifier.updateAuthState]).
///
/// Widgets reading this provider can decide whether to show auth gates.
final guestModeProvider = StateProvider<bool>((ref) {
  return GuestSessionService.isActive;
});
