import 'package:web/web.dart' as web;

String currentBrowserRoute(String fallback) {
  final location = web.window.location;
  final route = '${location.pathname}${location.search}${location.hash}';
  return route.isEmpty ? fallback : route;
}
