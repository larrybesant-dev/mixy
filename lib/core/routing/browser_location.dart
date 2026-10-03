import 'browser_location_stub.dart'
    if (dart.library.js_interop) 'browser_location_web.dart' as implementation;

String currentBrowserRoute(String fallback) =>
    implementation.currentBrowserRoute(fallback);
