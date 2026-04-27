// Corrected FirebaseOptions for MixVy
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    const platform = String.fromEnvironment(
      'FLUTTER_FIRE_PLATFORM',
      defaultValue: 'web',
    );

    switch (platform) {
      case 'windows':
        return windows;
      case 'web':
      default:
        return web;
    }
  }

  /// FirebaseOptions for web
  // Note: apiKey is public and safe to hardcode in web apps
  static FirebaseOptions get web => FirebaseOptions(
      apiKey: 'AIzaSyB8KXjs0EqnJQdbaKVkX9nwsj07RK2ffM4',
        authDomain: 'mix-and-mingle-v2.firebaseapp.com',
        projectId: 'mix-and-mingle-v2',
        storageBucket: 'mix-and-mingle-v2.firebasestorage.app',
        messagingSenderId: '980846719834',
        appId: '1:980846719834:web:4f26d018877528c3077963',
        measurementId: 'G-DRXWK1PPEK',
        databaseURL: 'https://mix-and-mingle-v2.firebaseio.com',
      );

  /// FirebaseOptions for Windows
  static FirebaseOptions get windows => FirebaseOptions(
      apiKey: 'AIzaSyB8KXjs0EqnJQdbaKVkX9nwsj07RK2ffM4',
        authDomain: 'mix-and-mingle-v2.firebaseapp.com',
        projectId: 'mix-and-mingle-v2',
        storageBucket: 'mix-and-mingle-v2.firebasestorage.app',
        messagingSenderId: '980846719834',
        appId: '1:980846719834:web:4f26d018877528c3077963',
        measurementId: 'G-DRXWK1PPEK',
        databaseURL: 'https://mix-and-mingle-v2.firebaseio.com',
      );
}
