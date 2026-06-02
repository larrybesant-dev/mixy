import 'package:firebase_auth/firebase_auth.dart';

import 'apple_sign_in_helper_stub.dart';

class AppleSignInHelperWeb implements AppleSignInHelper {
  @override
  Future<void> signInWithApple() async {
    final provider = OAuthProvider('apple.com');
    await FirebaseAuth.instance.signInWithPopup(provider);
  }

  @override
  Future<void> completePendingRedirectSignIn() async {
    // Web uses popup flow for Apple sign-in.
    return;
  }
}

AppleSignInHelper getAppleSignInHelper() => AppleSignInHelperWeb();
