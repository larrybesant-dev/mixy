String? evaluateAppRedirect({
  required String matchedLocation,
  required String? uid,
  required bool authLoading,
}) {
  if (authLoading) return null;

  final isAuth = uid != null && uid.isNotEmpty;

  if (!isAuth && matchedLocation != '/auth') return '/auth';
  if (isAuth && matchedLocation == '/auth') return '/home';

  return null;
}
