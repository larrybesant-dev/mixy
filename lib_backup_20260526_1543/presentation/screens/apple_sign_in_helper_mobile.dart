import 'package:firebase_auth/firebase_auth.dart';

import 'apple_sign_in_helper_stub.dart';

class AppleSignInHelperMobile implements AppleSignInHelper {
  @override
  Future<void> signInWithApple() async {
    final provider = OAuthProvider('apple.com');
    await FirebaseAuth.instance.signInWithProvider(provider);
  }

  @override
  Future<void> completePendingRedirectSignIn() async {
    // Redirect completion is not used for mobile in this flow.
    return;
  }
}

AppleSignInHelper getAppleSignInHelper() => AppleSignInHelperMobile();
