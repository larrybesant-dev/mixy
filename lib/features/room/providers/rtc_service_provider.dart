import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/rtc_room_service.dart';

/// Holds the live [RtcRoomService] instance for a room session.
///
/// Written by [LiveRoomScreen] after the RTC channel connects.
/// Auto-disposed when the room UI goes away so stale services do not leak
/// across sessions.
/// Keyed by roomId so concurrent rooms (future feature) stay isolated.
final rtcServiceProvider =
        StateProvider.autoDispose.family<RtcRoomService?, String>(
            (ref, roomId) => null,
        );
