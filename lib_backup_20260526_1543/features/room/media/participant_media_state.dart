import 'room_media_tier.dart';

class ParticipantMediaState {
  final String userId;
  final MediaTier tier;
  final bool isSpeaking;
  final bool isHost;
  final bool hasCameraOn;
  final int activityScore;

  const ParticipantMediaState({
    required this.userId,
    required this.tier,
    required this.isSpeaking,
    required this.isHost,
    required this.hasCameraOn,
    required this.activityScore,
  });

  ParticipantMediaState copyWith({
    MediaTier? tier,
    bool? isSpeaking,
    bool? isHost,
    bool? hasCameraOn,
    int? activityScore,
  }) {
    return ParticipantMediaState(
      userId: userId,
      tier: tier ?? this.tier,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isHost: isHost ?? this.isHost,
      hasCameraOn: hasCameraOn ?? this.hasCameraOn,
      activityScore: activityScore ?? this.activityScore,
    );
  }
}
