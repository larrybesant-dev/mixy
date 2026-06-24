// Speed Dating Service - DISABLED FOR V1 LAUNCH
// Re-enable in lib/_disabled/speed_dating/ after core features stabilize

class SpeedDatingService {
  SpeedDatingService();

  // Stub methods - Feature disabled for V1 launch
  Future<dynamic> getSpeedDatingRound(String roundId) async => null;
  Future<List<dynamic>> getActiveRoundsForEvent(String eventId) async => [];
  Future<List<dynamic>> getUserSpeedDatingResults(String userId) async => [];
  Future<List<String>> getMutualMatches(String userId) async => [];
  Future<String?> createSpeedDatingRound({
    required String eventId,
    required String name,
    required int duration,
    required List<String> participantIds,
  }) async =>
      null;
  Future<bool> joinSpeedDatingRound(String roundId, String userId) async =>
      false;
  Future<bool> leaveSpeedDatingRound(String roundId, String userId) async =>
      false;
  Future<bool> startSpeedDatingRound(String roundId) async => false;
  Future<bool> submitSpeedDatingResult({
    required String roundId,
    required String userId,
    required String matchedUserId,
    required bool userLiked,
    bool? matchedUserLiked,
  }) async =>
      false;
  Future<bool> advanceToNextRound(String roundId) async => false;
  Future<bool> endSpeedDatingRound(String roundId) async => false;
  Future<dynamic> findActiveSession(String eventId) async => null;
  Future<String?> createSession(Map<String, dynamic> sessionData) async => null;
  Future<dynamic> getSession(String sessionId) async => null;
  Future<bool> cancelSession(String sessionId) async => false;
  Future<bool> submitDecision(String roundId, String userId,
          String matchedUserId, bool liked) async =>
      false;
  Future<bool> startNextRound(String roundId) async => false;
  Future<bool> endSession(String roundId) async => false;

  // Additional stub methods for lobby/queue features
  Future<String?> joinQueue(String userId) async => null;
  Future<bool> leaveQueue(String sessionId, String userId) async => false;
  Stream<Map<String, dynamic>?> listenForMatch(
          String sessionId, String userId) =>
      Stream.value(null);
  Stream<Map<String, dynamic>?> listenToSessionStatus(String sessionId) =>
      Stream.value(null);
  Stream<Map<String, dynamic>?> listenToSession(String sessionId) =>
      Stream.value(null);
  Future<Map<String, dynamic>?> getUserInfo(String userId) async => null;
  Future<bool> leaveSession(String sessionId, String userId) async => false;
}
