import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'direct_conversation_service.dart';

class FirebaseDirectConversationService implements DirectConversationService {
  FirebaseDirectConversationService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<String> create({required String targetUserId}) async {
    final result = await _functions
        .httpsCallable('createDirectConversation')
        .call<Map<String, dynamic>>(<String, dynamic>{
      'targetUserId': targetUserId,
    }).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException(
        'Starting the conversation took too long. Please try again.',
      ),
    );
    final conversationId = result.data['conversationId'];
    if (conversationId is! String || conversationId.trim().isEmpty) {
      throw StateError('The server did not return a conversation.');
    }
    return conversationId.trim();
  }
}
