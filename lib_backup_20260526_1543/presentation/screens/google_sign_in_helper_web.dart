import 'package:firebase_auth/firebase_auth.dart';

import 'google_sign_in_helper_stub.dart';

class GoogleSignInHelperWeb implements GoogleSignInHelper {
  @override
  Future<void> signInWithGoogle() async {
    await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  }

  @override
  Future<void> completePendingRedirectSignIn() async {
    // Web now uses popup-based Google sign-in to avoid redirect-result
    // startup work that can fail before the app renders.
    return;
  }
}

GoogleSignInHelper getGoogleSignInHelper() => GoogleSignInHelperWeb();
