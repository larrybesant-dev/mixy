import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../repository/reaction_repository.dart';
import '../../../models/reaction_model.dart';

final reactionRepositoryProvider = Provider<ReactionRepository>((ref) {
  return ReactionRepository(ref.watch(firestoreProvider));
});

final reactionsStreamProvider = StreamProvider.autoDispose.family<List<ReactionModel>, ({String roomId, String messageId})>((ref, params) {
  return ref.read(reactionRepositoryProvider).reactionsStream(params.roomId, params.messageId);
});
