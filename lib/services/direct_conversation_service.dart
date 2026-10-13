abstract interface class DirectConversationService {
  Future<String> create({required String targetUserId});
}
