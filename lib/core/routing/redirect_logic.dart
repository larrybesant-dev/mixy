class RedirectEvaluation {
  const RedirectEvaluation({required this.redirectTo, required this.reason});

  final String? redirectTo;
  final String reason;
}

RedirectEvaluation evaluateAppRedirectWithReason({
  required String matchedLocation,
  required String? uid,
  required bool authLoading,
  required bool legalStateResolved,
  required bool hasAcceptedLegal,
}) {
  // Guest-browse routes: all read-only destinations reachable without an account.
  const _guestAllowedPrefixes = <String>[
    '/home',
    '/room',
    '/profile',
    '/auth',
    '/register',
    '/onboarding',
    '/legal',
    '/about',
  ];

RedirectEvaluation evaluateAppRedirectWithReason({
  required String matchedLocation,
  required String? uid,
  required bool authLoading,
  required bool legalStateResolved,
  required bool hasAcceptedLegal,
  bool isGuestMode = false,
}) {
  if (authLoading) {
    return const RedirectEvaluation(
      redirectTo: null,
      reason: 'auth_loading_hold',
    );
  }

  final isAuth = uid != null && uid.isNotEmpty;

  if (isAuth && !legalStateResolved) {
    return const RedirectEvaluation(
      redirectTo: null,
      reason: 'legal_loading_hold',
    );
  }

  // 1. Force unauthenticated users to /auth (unless skipping onboarding)
  if (!isAuth) {
    if (matchedLocation == '/auth' ||
        class RedirectEvaluation {
          const RedirectEvaluation({required this.redirectTo, required this.reason});

          final String? redirectTo;
          final String reason;
        }

        /// Routes (or prefixes) a guest (no Firebase UID) may visit in browse mode.
        bool _isGuestBrowseable(String loc) {
          const exact = <String>[
            '/home',
            '/auth',
            '/register',
            '/onboarding',
            '/legal',
            '/about',
          ];
          if (exact.contains(loc)) return true;
          // Read-only room preview and profile pages.
          if (loc.startsWith('/room/')) return true;
          if (loc.startsWith('/profile/')) return true;
          return false;
        }

        RedirectEvaluation evaluateAppRedirectWithReason({
          required String matchedLocation,
          required String? uid,
          required bool authLoading,
          required bool legalStateResolved,
          required bool hasAcceptedLegal,
          /// When true the user chose to browse without signing in.
          /// Read-only routes are permitted; write actions are gated in-UI by
          /// [GuestAuthGate].
          bool isGuestMode = false,
        }) {
          if (authLoading) {
            return const RedirectEvaluation(
              redirectTo: null,
              reason: 'auth_loading_hold',
            );
          }

          final isAuth = uid != null && uid.isNotEmpty;

          if (isAuth && !legalStateResolved) {
            return const RedirectEvaluation(
              redirectTo: null,
              reason: 'legal_loading_hold',
            );
          }

          // ── Unauthenticated ────────────────────────────────────────────────────
          if (!isAuth) {
            // Guest-browse: allow read-only destinations without an account.
            if (isGuestMode && _isGuestBrowseable(matchedLocation)) {
              return const RedirectEvaluation(
                redirectTo: null,
                reason: 'guest_browse_allowed',
              );
            }

            // Public auth routes always allowed.
            if (matchedLocation == '/auth' ||
                matchedLocation == '/register' ||
                matchedLocation == '/onboarding') {
              return const RedirectEvaluation(
                redirectTo: null,
                reason: 'signed_out_allowed_public_auth_routes',
              );
            }

            return const RedirectEvaluation(
              redirectTo: '/auth',
              reason: 'signed_out_redirect_to_auth',
            );
          }

          // ── Authenticated ──────────────────────────────────────────────────────

          // 2. Force authenticated users who haven't accepted legal to /onboarding.
          if (!hasAcceptedLegal && matchedLocation != '/onboarding') {
            return const RedirectEvaluation(
              redirectTo: '/onboarding',
              reason: 'signed_in_without_legal_redirect_to_onboarding',
            );
          }

          // 3. Prevent authenticated + onboarded users from looping on /auth or /onboarding.
          if (isAuth &&
              hasAcceptedLegal &&
              (matchedLocation == '/auth' || matchedLocation == '/onboarding')) {
            return const RedirectEvaluation(
              redirectTo: '/home',
              reason: 'signed_in_with_legal_redirect_to_home',
            );
          }

          return const RedirectEvaluation(
            redirectTo: null,
            reason: 'no_redirect_keep_location',
          );
        }

        String? evaluateAppRedirect({
          required String matchedLocation,
          required String? uid,
          required bool authLoading,
          required bool legalStateResolved,
          required bool hasAcceptedLegal,
          bool isGuestMode = false,
        }) {
          final evaluation = evaluateAppRedirectWithReason(
            matchedLocation: matchedLocation,
            uid: uid,
            authLoading: authLoading,
            legalStateResolved: legalStateResolved,
            hasAcceptedLegal: hasAcceptedLegal,
            isGuestMode: isGuestMode,
          );
          return evaluation.redirectTo;
        }
