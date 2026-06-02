/// Calculates a priority score for a participant used by the media tier engine.
///
/// Higher score → higher tier (fullVideo > lowVideo > audioOnly).
int calculateMediaScore({
  required bool isHost,
  required bool isSpeaking,
  required bool recentlySpoke,
  required bool hasCameraOn,
  required int idleSeconds,
}) {
  int score = 0;

  if (isHost) score += 100;
  if (isSpeaking) score += 80;
  if (recentlySpoke) score += 50;
  if (hasCameraOn) score += 20;

  score -= (idleSeconds ~/ 10);

  return score;
}
