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

  // 2. Force authenticated users who haven't accepted legal/onboarding to /onboarding
  if (!hasAcceptedLegal && matchedLocation != '/onboarding') {
    return const RedirectEvaluation(
      redirectTo: '/onboarding',
      reason: 'signed_in_without_legal_redirect_to_onboarding',
    );
  }

  // 3. Prevent authenticated + onboarded users from seeing /auth or /onboarding
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
}) {
  final evaluation = evaluateAppRedirectWithReason(
    matchedLocation: matchedLocation,
    uid: uid,
    authLoading: authLoading,
    legalStateResolved: legalStateResolved,
    hasAcceptedLegal: hasAcceptedLegal,
  );
  return evaluation.redirectTo;
}
