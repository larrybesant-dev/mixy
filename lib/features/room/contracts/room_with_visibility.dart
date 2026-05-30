import 'package:flutter/material.dart';
import 'package:mixvy/features/room/contracts/room_visibility_contract.dart';
import 'package:mixvy/models/room_model.dart';

class RoomWithVisibility {
  const RoomWithVisibility({required this.room, required this.visibility});

  final RoomModel room;
  final RoomVisibilityResult visibility;

  RoomVisibilityTier get tier => visibility.tier;
  bool get isVisible => visibility.isVisible;
}




