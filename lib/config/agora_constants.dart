import 'app_env.dart';

/// Loads Agora App ID from .env file using flutter_dotenv.
/// Ensure you call `await dotenv.load()` in main() before using this constant.
class AgoraConstants {
  static String get appId => AppEnv.agoraAppId;

  static const String tokenEndpoint =
      'https://us-central1-mix-and-mingle-v2.cloudfunctions.net/generateAgoraToken';
}



