import 'dart:io' show Platform;

List<String> getCommandLineArgs() {
  try {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return Platform.executableArguments;
    }
  } catch (_) {}
  return const [];
}
