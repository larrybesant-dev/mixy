// Desktop window service for pop-out whisper windows.
//
// On desktop (Windows/macOS/Linux) this works by launching a second instance
// of the same executable with a `--popout-whisper=userId` argument.
// The app's `main()` already handles this flag and renders a bare ChatScreen
// via the /whisper route.
//
// This file is imported only on non-web desktop platforms via a conditional
// export in `desktop_window_service.dart`.
import 'dart:io';

class DesktopWindowService {
  /// Opens a whisper pop-out window for [userId]/[username].
  Future<void> openWhisperWindow(String userId, String username) async {
    final exePath = Platform.resolvedExecutable;
    try {
      await Process.start(
          exePath,
          [
            '--popout-whisper=$userId',
          ],
          mode: ProcessStartMode.detached);
    } catch (_) {
      // Silently ignore — desktop pop-out is a best-effort feature.
    }
  }

  /// Opens a cam pop-out window for [userId].
  Future<void> openCamWindow(String userId) async {
    final exePath = Platform.resolvedExecutable;
    try {
      await Process.start(
          exePath,
          [
            '--popout-cam=$userId',
          ],
          mode: ProcessStartMode.detached);
    } catch (_) {}
  }
}
