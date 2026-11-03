import 'package:flutter_webrtc/flutter_webrtc.dart';

export 'outgoing_audio_gain_stub.dart'
    if (dart.library.js_interop) 'outgoing_audio_gain_web.dart';

abstract interface class OutgoingAudioGain {
  MediaStreamTrack get outputTrack;

  Future<void> setGain(double gain);

  Future<void> dispose();
}
