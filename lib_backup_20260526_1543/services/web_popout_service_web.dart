// Web implementation – uses package:web window.open for pop-out panels.
import 'package:web/web.dart' as web;

class WebPopoutService {
  /// Opens a whisper (DM) window for [userId] with [username] as the title.
  void openWhisperWindow(String userId, String username) {
    web.window.open(
      '/whisperif (userId != null) userId=$userId',
      'mixvy_whisper_$userId',
      'width=420,height=640,resizable=yes,scrollbars=yes',
    );
  }

  /// Opens a camera/cam window for [userId].
  void openCamWindow(String userId) {
    web.window.open(
      '/camif (userId != null) userId=$userId',
      'mixvy_cam_$userId',
      'width=520,height=480,resizable=yes',
    );
  }
}
