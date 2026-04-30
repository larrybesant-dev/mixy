import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/providers/guest_mode_provider.dart';
import 'package:mixvy/core/providers/session_capabilities_provider.dart';

/// Gold / Wine / Cream brand tokens (duplicated here to avoid a
/// cross-cutting import; keep in sync with AppTheme if you centralise).
const _gold = Color(0xFFD4AF37);
const _wine = Color(0xFF781E2B);
const _surface = Color(0xFF0B0B0B);
const _cream = Color(0xFFF7EDE2);

/// Shows an auth gate bottom sheet when the current user is browsing as a
/// guest and tries to perform a write action (join room, follow, send
/// message, etc.).
///
/// Usage:
/// ```dart
/// if (!await GuestAuthGate.gate(context, ref)) return;
/// // ... proceed with the action
/// ```
///
/// Returns `true` if the user already has an account (or just signed in).
/// Returns `false` if the user is a guest and was shown the gate.
abstract final class GuestAuthGate {
  static Future<bool> requireCapability(
    BuildContext context,
    WidgetRef ref,
    SessionCapability capability,
  ) async {
    final session = ref.read(sessionCapabilitiesProvider);
    if (session.has(capability)) {
      return true;
    }
    await _showGateSheet(
      context,
      actionHint: _defaultActionHintFor(capability),
    );
    return false;
  }

  static Future<bool> requireMessaging(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.sendMessage);
  }

  static Future<bool> requireCapabilityFromContext(
    BuildContext context,
    SessionCapability capability,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final session = container.read(sessionCapabilitiesProvider);
    if (session.has(capability)) {
      return true;
    }
    await _showGateSheet(
      context,
      actionHint: _defaultActionHintFor(capability),
    );
    return false;
  }

  static Future<bool> requireConversationStart(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.startConversation);
  }

  static Future<bool> requireFollow(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.followUser);
  }

  static Future<bool> requireRoomCreation(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.createRoom);
  }

  static Future<bool> requireRoomJoin(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.joinRoom);
  }

  static Future<bool> requirePostCreation(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.createPost);
  }

  static Future<bool> requireStoryCreation(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.createStory);
  }

  static Future<bool> requireGroupCreation(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.createGroup);
  }

  static Future<bool> requireProfileEdit(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.editProfile);
  }

  static Future<bool> requireRoomInvite(
    BuildContext context,
    WidgetRef ref,
  ) {
    return requireCapability(context, ref, SessionCapability.inviteToRoom);
  }

  static String _defaultActionHintFor(SessionCapability capability) {
    switch (capability) {
      case SessionCapability.sendMessage:
        return 'send messages';
      case SessionCapability.startConversation:
        return 'start conversations';
      case SessionCapability.followUser:
        return 'follow users';
      case SessionCapability.createRoom:
        return 'start a room';
      case SessionCapability.joinRoom:
        return 'join live rooms';
      case SessionCapability.createPost:
        return 'create posts';
      case SessionCapability.createStory:
        return 'create stories';
      case SessionCapability.createGroup:
        return 'create groups';
      case SessionCapability.editProfile:
        return 'edit your profile';
      case SessionCapability.inviteToRoom:
        return 'send room invites';
    }
  }

  /// Checks whether the user is in guest mode.  If so, shows the gate bottom
  /// sheet and returns `false`.  Otherwise returns `true` immediately.
  static Future<bool> gate(
    BuildContext context,
    WidgetRef ref, {
    String? actionHint,
  }) async {
    final isGuest = ref.read(guestModeProvider);
    return gateForGuestFlag(context, isGuest: isGuest, actionHint: actionHint);
  }

  /// Same as [gate] but accepts a plain boolean guest flag. Useful in
  /// widgets that do not have a [WidgetRef] (for example plain StatelessWidget
  /// helpers that can still read providers via `ProviderScope.containerOf`).
  static Future<bool> gateForGuestFlag(
    BuildContext context, {
    required bool isGuest,
    String? actionHint,
  }) async {
    if (!isGuest) return true;
    await _showGateSheet(context, actionHint: actionHint);
    return false;
  }

  static Future<void> _showGateSheet(
    BuildContext context, {
    String? actionHint,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GuestGateSheet(actionHint: actionHint),
    );
  }
}

class _GuestGateSheet extends StatelessWidget {
  const _GuestGateSheet({this.actionHint});
  final String? actionHint;

  @override
  Widget build(BuildContext context) {
    final hint = actionHint ?? 'this feature';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: _gold, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Create a free account',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _cream,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You need an account to use $hint.\nJoin MixVy — it only takes a moment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(fontSize: 14, color: Colors.white60),
          ),
          const SizedBox(height: 28),
          // Sign Up — solid gold
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.raleway(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/register');
              },
              child: const Text('SIGN UP FOR FREE'),
            ),
          ),
          const SizedBox(height: 12),
          // Sign In — outline gold
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.raleway(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/auth');
              },
              child: const Text('SIGN IN'),
            ),
          ),
          const SizedBox(height: 16),
          // Keep browsing
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Keep browsing',
              style: GoogleFonts.raleway(
                fontSize: 13,
                color: _wine,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
