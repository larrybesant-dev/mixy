import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../auth/controllers/auth_controller.dart';
import 'top_eight_repository.dart';

final topEightIdsProvider = StreamProvider.autoDispose.family<List<String>, String>((ref, userId) {
  return ref.watch(topEightRepositoryProvider).watchTopEightIds(userId);
});

final topEightUsersProvider = FutureProvider.autoDispose.family<List<UserModel>, String>((ref, userId) async {
  final ids = await ref.watch(topEightIdsProvider(userId).future);
  return ref.watch(topEightRepositoryProvider).getUsersFromIds(ids);
});

final topEightControllerProvider = StateNotifierProvider.autoDispose<TopEightController, AsyncValue<List<String>>>((ref) {
  final userId = ref.watch(authControllerProvider).uid;
  if (userId == null) return TopEightController(ref, const AsyncValue.data([]));
  
  final idsAsync = ref.watch(topEightIdsProvider(userId));
  return TopEightController(ref, idsAsync);
});

class TopEightController extends StateNotifier<AsyncValue<List<String>>> {
  final Ref _ref;

  TopEightController(this._ref, AsyncValue<List<String>> initialState) : super(initialState);

  Future<void> addToTopEight(String friendId) async {
    final userId = _ref.read(authControllerProvider).uid;
    if (userId == null) return;

    final currentIds = state.value ?? [];
    if (currentIds.length >= 8) {
      throw Exception('You can only have up to 8 friends in your Top 8.');
    }
    if (currentIds.contains(friendId)) return;

    final updatedIds = [...currentIds, friendId];
    await _ref.read(topEightRepositoryProvider).updateTopEight(userId, updatedIds);
  }

  Future<void> removeFromTopEight(String friendId) async {
    final userId = _ref.read(authControllerProvider).uid;
    if (userId == null) return;

    final currentIds = state.value ?? [];
    final updatedIds = currentIds.where((id) => id != friendId).toList();
    await _ref.read(topEightRepositoryProvider).updateTopEight(userId, updatedIds);
  }

  Future<void> reorderTopEight(int oldIndex, int newIndex) async {
    final userId = _ref.read(authControllerProvider).uid;
    if (userId == null) return;

    final currentIds = List<String>.from(state.value ?? []);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = currentIds.removeAt(oldIndex);
    currentIds.insert(newIndex, item);

    await _ref.read(topEightRepositoryProvider).updateTopEight(userId, currentIds);
  }
}




