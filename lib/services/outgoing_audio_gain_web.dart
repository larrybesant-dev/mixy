import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart';
import 'package:web/web.dart' as web;

import 'outgoing_audio_gain.dart';

Future<OutgoingAudioGain> createOutgoingAudioGain(
  MediaStreamTrack sourceTrack, {
  required double initialGain,
}) async {
  if (sourceTrack is! MediaStreamTrackWeb) {
    throw StateError('Web audio gain requires a browser media track.');
  }

  final context = web.AudioContext();
  final inputStream = web.MediaStream();
  inputStream.addTrack(sourceTrack.jsTrack);
  final source = context.createMediaStreamSource(inputStream);
  final gainNode = context.createGain();
  final destination = context.createMediaStreamDestination();
  gainNode.gain.value = initialGain.clamp(0.0, 2.0);
  source.connect(gainNode);
  gainNode.connect(destination);

  final outputTracks = destination.stream.getAudioTracks().toDart;
  if (outputTracks.isEmpty) {
    await context.close().toDart;
    throw StateError('Unable to create an outgoing browser audio track.');
  }

  await context.resume().toDart;
  return _WebOutgoingAudioGain(
    context: context,
    source: source,
    gainNode: gainNode,
    destination: destination,
    outputTrack: MediaStreamTrackWeb(outputTracks.first),
  );
}

class _WebOutgoingAudioGain implements OutgoingAudioGain {
  _WebOutgoingAudioGain({
    required this.context,
    required this.source,
    required this.gainNode,
    required this.destination,
    required this.outputTrack,
  });

  final web.AudioContext context;
  final web.MediaStreamAudioSourceNode source;
  final web.GainNode gainNode;
  final web.MediaStreamAudioDestinationNode destination;

  @override
  final MediaStreamTrackWeb outputTrack;

  @override
  Future<void> setGain(double gain) async {
    gainNode.gain.value = gain.clamp(0.0, 2.0);
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
  }

  @override
  Future<void> dispose() async {
    source.disconnect();
    gainNode.disconnect();
    await outputTrack.stop();
    await context.close().toDart;
  }
}
