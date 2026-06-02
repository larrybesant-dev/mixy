import 'apple_sign_in_helper_stub.dart';
import 'apple_sign_in_helper_stub.dart'
    if (dart.library.io) 'apple_sign_in_helper_mobile.dart'
    if (dart.library.html) 'apple_sign_in_helper_web.dart' as implementation;

export 'apple_sign_in_helper_stub.dart';

AppleSignInHelper getAppleSignInHelper() =>
    implementation.getAppleSignInHelper();
