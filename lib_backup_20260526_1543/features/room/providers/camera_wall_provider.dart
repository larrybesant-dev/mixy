import 'package:flutter_riverpod/flutter_riverpod.dart';

final cameraWallOverflowPageProvider =
    StateProvider.autoDispose.family<int, String>((ref, roomId) => 0);
