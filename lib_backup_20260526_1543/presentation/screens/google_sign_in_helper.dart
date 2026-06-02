import 'google_sign_in_helper_stub.dart';
import 'google_sign_in_helper_stub.dart'
    if (dart.library.io) 'google_sign_in_helper_mobile.dart'
    if (dart.library.html) 'google_sign_in_helper_web.dart' as implementation;

export 'google_sign_in_helper_stub.dart';

GoogleSignInHelper getGoogleSignInHelper() =>
    implementation.getGoogleSignInHelper();
