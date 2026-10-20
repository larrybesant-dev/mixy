abstract class GoogleSignInHelper {
  bool get isSupported;

  Future<void> signInWithGoogle();

  Future<void> completePendingRedirectSignIn();
}

class _UnsupportedGoogleSignInHelper implements GoogleSignInHelper {
  @override
  bool get isSupported => false;

  @override
  Future<void> signInWithGoogle() async {
    throw UnsupportedError('Google Sign-In is not supported on this platform');
  }

  @override
  Future<void> completePendingRedirectSignIn() async {
    // No-op on unsupported platforms.
  }
}

GoogleSignInHelper getGoogleSignInHelper() => _UnsupportedGoogleSignInHelper();




