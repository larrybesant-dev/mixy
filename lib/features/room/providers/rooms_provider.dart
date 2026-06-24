/// Rooms Provider - State management for rooms list
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/room.dart';

/// Rooms state model
class RoomsState {
  final List<Room> rooms;
  final bool isLoading;
  final String? error;

  RoomsState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
  });

  RoomsState copyWith({
    List<Room>? rooms,
    bool? isLoading,
    String? error,
  }) =>
      RoomsState(
        rooms: rooms ?? this.rooms,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

/// Rooms notifier (Riverpod 3.x Notifier)
class RoomsNotifier extends Notifier<RoomsState> {
  @override
  RoomsState build() => RoomsState();

  void setCategory(String? category) {
    // TODO: Filter rooms by category
  }

  Future<String?> createRoom({
    required String name,
    String? description,
    String? category,
  }) async {
    // TODO: Implement room creation
    return null;
  }
}

/// Rooms provider
final roomsProvider =
    NotifierProvider<RoomsNotifier, RoomsState>(RoomsNotifier.new);
