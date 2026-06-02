// Conditional export: on web use Web Audio oscillator implementation;
// on non-web use haptic-feedback stub that compiles on VM.
export 'room_audio_cues_stub.dart'
    if (dart.library.js_interop) 'room_audio_cues_web.dart';
