import 'dart:async';

void registerBrowserUnloadListener(FutureOr<void> Function() onUnload) {
  // No-op on non-web platforms
}

void unregisterBrowserUnloadListener() {
  // No-op on non-web platforms
}
