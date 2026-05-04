import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/room_model.dart';

final roomListProvider = StateProvider<List<RoomModel>>((ref) => []);
