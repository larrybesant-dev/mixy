// Conditional re-export: web implementation on web, stub on native platforms.
export 'agora_web_bridge_v2_stub.dart'
    if (dart.library.js_interop) 'agora_web_bridge_v2_web.dart';
