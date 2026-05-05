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
  if (authLoading) {
    return const RedirectEvaluation(
      redirectTo: null,
      reason: 'auth_loading_non_blocking',
    );
  }

  if (matchedLocation == '/auth') {
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

  return const RedirectEvaluation(
    redirectTo: null,
    reason: 'shell_first_keep_location',
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
