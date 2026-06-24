// Web implementation: registers an HTML div element as a platform view factory.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerVideoViewFactory(String viewId, String elementId) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int id) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = elementId;
      div.style.width = '100%';
      div.style.height = '100%';
      div.style.objectFit = 'cover';
      return div.toJSBox;
    },
  );
}
