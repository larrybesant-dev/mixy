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
  final isAuth = uid != null && uid.isNotEmpty;

  // ── 1. BOOTSTRAP GATE ──────────────────────────────────────────────────────
  // If we are still determining the auth state (e.g. Firebase initializing),
  // we MUST NOT redirect. Redirecting to /auth here would overwrite the deep
  // link URL before the app knows who the user is.
  if (authLoading) {
    return const RedirectEvaluation(
      redirectTo: null,
      reason: 'auth_loading_preserve_location',
    );
  }

  // ── 2. PUBLIC ROUTES ───────────────────────────────────────────────────────
  // Routes that are allowed regardless of auth state.
  final isAuthRoute = matchedLocation == '/auth' ||
      matchedLocation == '/register' ||
      matchedLocation == '/forgot-password' ||
      matchedLocation == '/onboarding';

  // Guest access to rooms is allowed — LiveRoomScreen handles its own
  // internal gates for adult content and messaging.
  final isRoomRoute = matchedLocation.startsWith('/rooms/room/');

  final isPublicRoute = isAuthRoute || isRoomRoute;

  // ── 3. AUTH ROUTE SPECIAL CASE ─────────────────────────────────────────────
  // If user is already signed in, don't let them stay on /auth or /register.
  if (isAuthRoute) {
    return isAuth
        ? const RedirectEvaluation(
            redirectTo: '/home',
            reason: 'signed_in_redirect_to_home',
          )
        : const RedirectEvaluation(
            redirectTo: null,
            reason: 'signed_out_allowed_auth_route',
          );
  }

  // ── 4. PRIVATE ROUTES ──────────────────────────────────────────────────────
  if (!isAuth && !isPublicRoute) {
    return const RedirectEvaluation(
      redirectTo: '/auth',
      reason: 'signed_out_redirect_to_auth',
    );
  }

  return const RedirectEvaluation(
    redirectTo: null,
    reason: 'allow_navigation',
  );
}

String? evaluateAppRedirect({
  required String matchedLocation,
  required String? uid,
  required bool authLoading,
  required bool legalStateResolved,
  required bool hasAcceptedLegal,
}) {
  return evaluateAppRedirectWithReason(
    matchedLocation: matchedLocation,
    uid: uid,
    authLoading: authLoading,
    legalStateResolved: legalStateResolved,
    hasAcceptedLegal: hasAcceptedLegal,
  ).redirectTo;
}
