// Conditional export: on web (dart:js_interop available) use the real
// browser-native WebRTC implementation; on VM/native use the stub so that
// unit tests compile without requiring web-only Dart libraries.
export 'webrtc_room_service_stub.dart'
    if (dart.library.js_interop) 'webrtc_room_service.dart';
