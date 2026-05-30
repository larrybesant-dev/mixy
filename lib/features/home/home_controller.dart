import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/models/room_model.dart';

class HomeController extends StateNotifier<List<RoomModel>> {
  HomeController() : super([]);

  void addRoom(RoomModel room) {
    state = [...state, room];
  }

  void removeRoom(String roomId) {
    state = state.where((room) => room.id != roomId).toList();
  }
}

final homeControllerProvider =
    StateNotifierProvider<HomeController, List<RoomModel>>(
      (ref) => HomeController(),
    );




