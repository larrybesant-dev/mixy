/// Non-web stub for [RoomAudioCues].
///
/// All public cues are true no-ops on VM / native builds.
/// Web Audio oscillator tones are handled by [room_audio_cues_web.dart].
class RoomAudioCues {
  RoomAudioCues._();

  static final RoomAudioCues instance = RoomAudioCues._();

  // ignore: avoid_positional_boolean_parameters
  void playUserJoined() {}
  void playUserLeft() {}
  void playGiftReceived() {}
  void playHandRaised() {}
  void playMicApproved() {}
  void playNewmessage() {}
  void playPrivatemessage() {}
  void playBuzz() {}
  void dispose() {}
}
