abstract class AppleSignInHelper {
  Future<void> signInWithApple();

  Future<void> completePendingRedirectSignIn();
}

class _UnsupportedAppleSignInHelper implements AppleSignInHelper {
  @override
  Future<void> signInWithApple() async {
    throw UnsupportedError('Apple Sign-In is not supported on this platform');
  }

  @override
  Future<void> completePendingRedirectSignIn() async {
    // No-op on unsupported platforms.
  }
}

AppleSignInHelper getAppleSignInHelper() => _UnsupportedAppleSignInHelper();
