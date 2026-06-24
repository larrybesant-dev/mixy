// lib/providers/agora_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/agora/agora_service.dart';

final agoraServiceProvider = Provider<AgoraService>((ref) => AgoraService());
