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
  // Legal acceptance is enforced in feature flows, not in startup routing.
  // Keep parameters for backward-compatible callsites.
  final _ = legalStateResolved;
  final __ = hasAcceptedLegal;

  if (authLoading) {
    return const RedirectEvaluation(
      redirectTo: null,
      reason: 'auth_loading_hold',
    );
  }

  final isAuth = uid != null && uid.isNotEmpty;

  // ── Unauthenticated ────────────────────────────────────────────────────
  if (!isAuth) {
    // Public auth routes always allowed.
    if (matchedLocation == '/auth' || matchedLocation == '/register') {
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
  if (matchedLocation == '/auth') {
    return const RedirectEvaluation(
      redirectTo: '/home',
      reason: 'signed_in_redirect_to_home',
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
}) {
  return evaluateAppRedirectWithReason(
    matchedLocation: matchedLocation,
    uid: uid,
    authLoading: authLoading,
    legalStateResolved: legalStateResolved,
    hasAcceptedLegal: hasAcceptedLegal,
  ).redirectTo;
}
