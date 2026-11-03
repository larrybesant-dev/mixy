import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_sign_in_helper_stub.dart';

class GoogleSignInHelperMobile implements GoogleSignInHelper {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> signInWithGoogle() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Google Sign-In is not supported on ${defaultTargetPlatform.name}',
      );
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  @override
  Future<void> completePendingRedirectSignIn() async {
    // Mobile flows don't require this.
    return;
  }
}

GoogleSignInHelper getGoogleSignInHelper() => GoogleSignInHelperMobile();
