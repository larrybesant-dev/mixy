// lib/core/stubs/app_stubs.dart
// Temporary stubs to unblock builds. Replace with real implementations.

import 'package:flutter/material.dart';

class MixMingleTheme {
  static TextStyle get body => const TextStyle(fontSize: 14);
  static ThemeData get light => ThemeData.light();
  static ThemeData get dark => ThemeData.dark();
  static double get spacing => 8.0;
  static double get radius => 12.0;
  static Color get surface => Colors.white;
  static List<BoxShadow> get shadow => [];
  static Color get error => Colors.red;
  static Color get accent => Colors.blueAccent;
  static Color get success => Colors.green;
  static Color get secondary => Colors.grey;
}

class RoomService {
  Future<void> joinRoom(String id) async {}
  Future<void> leaveRoom() async {}
}

final RoomService roomService = RoomService();

typedef NotificationProvider = dynamic;
