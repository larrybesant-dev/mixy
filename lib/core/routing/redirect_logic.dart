class RedirectEvaluation {
  const RedirectEvaluation({required this.redirectTo, required this.reason});

  final String? redirectTo;
  final String reason;
}

/// Routes (or prefixes) a guest (no Firebase UID) may visit in browse mode.
/// NOTE: /room/* is intentionally NOT listed here because adult rooms must be
/// gated. The router's /room/:id builder performs the isAdult check at render
/// time; unauthenticated users reaching an adult room are pushed to /auth.
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
  // Profile pages are public previews.
  if (loc.startsWith('/profile/')) return true;
  // Non-adult room previews are allowed. Adult rooms are blocked at the
  // builder level — guests who land on an adult room are sent to /auth.
  if (loc.startsWith('/room/')) return true;
  return false;
}

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

  // Safety: Prevent permanent loading state if legal settings never arrive.
  if (isAuth && !legalStateResolved && matchedLocation != '/error') {
    // Allow it to stay for now, but in Phase 3 we'll add a timeout guard in app.dart
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

  // Force authenticated users who haven't accepted legal to /onboarding.
  if (!hasAcceptedLegal && matchedLocation != '/onboarding') {
    return const RedirectEvaluation(
      redirectTo: '/onboarding',
      reason: 'signed_in_without_legal_redirect_to_onboarding',
    );
  }

  // Prevent authenticated + onboarded users from looping on /auth or /onboarding.
  if (hasAcceptedLegal &&
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
  return evaluateAppRedirectWithReason(
    matchedLocation: matchedLocation,
    uid: uid,
    authLoading: authLoading,
    legalStateResolved: legalStateResolved,
    hasAcceptedLegal: hasAcceptedLegal,
    isGuestMode: isGuestMode,
  ).redirectTo;
}
