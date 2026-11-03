import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'outgoing_audio_gain.dart';

Future<OutgoingAudioGain> createOutgoingAudioGain(
  MediaStreamTrack sourceTrack, {
  required double initialGain,
}) async {
  return _PassThroughAudioGain(sourceTrack);
}

class _PassThroughAudioGain implements OutgoingAudioGain {
  _PassThroughAudioGain(this.outputTrack);

  @override
  final MediaStreamTrack outputTrack;

  @override
  Future<void> setGain(double gain) async {}

  @override
  Future<void> dispose() async {}
}
