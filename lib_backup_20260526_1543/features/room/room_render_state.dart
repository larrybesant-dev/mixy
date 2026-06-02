import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/live_room_media_controller.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout axis
// ─────────────────────────────────────────────────────────────────────────────

/// What the left (stage / cams) column should display.
///
/// Determined purely by session and stream presence. System health never
/// influences this value — errors overlay the layout rather than changing it.
enum StageViewMode {
  /// RTC service not yet initialised (pre-connect or post-disconnect).
  noSession,

  /// RTC connected; no cameras active. Show the social stage spotlight.
  spotlight,

  /// RTC connected and at least one camera tile is visible. Show camera wall.
  cameraWall,
}

// ─────────────────────────────────────────────────────────────────────────────
// Health axis
// ─────────────────────────────────────────────────────────────────────────────

/// The system-health signal for the RTC session.
///
/// This drives overlay badges and banners, NOT layout decisions.
enum RoomSystemCondition {
  /// Session healthy or not yet started.
  healthy,

  /// RTC is actively reconnecting after a transient drop. The connection
  /// still exists but media may be interrupted.
  reconnecting,

  /// Media quality is degraded (packet loss / jitter) but the session has
  /// not fully dropped. Shows a "poor connection" indicator.
  unstable,

  /// A non-recoverable or reported error is present; shows the error banner
  /// with a retry action.
  failed,
}

// ─────────────────────────────────────────────────────────────────────────────
// Composite render-state object
// ─────────────────────────────────────────────────────────────────────────────

/// Single object that drives all rendering decisions on the live room screen.
///
/// The UI is a pure function of this value:
/// - [layout] → what the stage/cams column shows
/// - [condition] → which health overlay (if any) is shown
/// - [errormessage] → text for the error banner when [condition] is [failed]
///
/// Both axes are orthogonal: a [failed] condition does not change [layout].
class RoomRenderState {
  const RoomRenderState({
    required this.layout,
    required this.condition,
    this.errormessage,
  });

  /// Layout axis: what the stage/cams column should display.
  final StageViewMode layout;

  /// Health axis: current system condition of the RTC session.
  final RoomSystemCondition condition;

  /// Human-readable error string when [condition] is [RoomSystemCondition.failed].
  final String? errormessage;

  bool get hasError => condition == RoomSystemCondition.failed;
  bool get isReconnecting => condition == RoomSystemCondition.reconnecting;
  bool get isUnstable => condition == RoomSystemCondition.unstable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomRenderState &&
          layout == other.layout &&
          condition == other.condition &&
          errormessage == other.errormessage;

  @override
  int get hashCode => Object.hash(layout, condition, errormessage);
}

// ─────────────────────────────────────────────────────────────────────────────
// Reducer: derives RoomRenderState from upstream provider state
// ─────────────────────────────────────────────────────────────────────────────
//
// This is the single place where layout + health derivation lives.
// The UI never recomputes this — it only reads the emitted value.

/// Derives [RoomRenderState] from [LiveRoomMediaState].
///
/// [hasVideoStreams] must be passed by the caller because stream presence is
/// an RTC-service signal that lives outside [LiveRoomMediaState].
RoomRenderState deriveRoomRenderState({
  required LiveRoomMediaState mediaState,
  required bool hasRtcService,
  required bool hasVideoStreams,
}) {
  // ── Health axis ──────────────────────────────────────────────────────────
  final RoomSystemCondition condition;
  if (mediaState.callError != null) {
    condition = RoomSystemCondition.failed;
  } else if (mediaState.phase == LiveRoomMediaPhase.reconnecting) {
    condition = RoomSystemCondition.reconnecting;
  } else if (mediaState.phase == LiveRoomMediaPhase.failed) {
    // phase=failed but no callError string = silent failure; treat as unstable
    // until a human-readable error is propagated.
    condition = RoomSystemCondition.unstable;
  } else {
    condition = RoomSystemCondition.healthy;
  }

  // ── Layout axis ──────────────────────────────────────────────────────────
  // Layout is determined by session + stream presence, never by health.
  final StageViewMode layout;
  if (!hasRtcService) {
    layout = StageViewMode.noSession;
  } else if (hasVideoStreams) {
    layout = StageViewMode.cameraWall;
  } else {
    layout = StageViewMode.spotlight;
  }

  return RoomRenderState(
    layout: layout,
    condition: condition,
    errormessage: mediaState.callError,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

/// A [Provider.family] that emits [RoomRenderState] for a given [roomId].
///
/// The screen watches this provider and renders as a pure function of its
/// value. No layout or health logic should live inside the screen widget.
///
/// Note: [hasVideoStreams] must be provided by the caller because it depends
/// on the live [RtcRoomService] instance which is managed by the screen's
/// [State] object (not a Riverpod provider). Pass it via
/// [roomRenderStateProvider(roomId).overrideWith(...)] if you move the service
/// to a provider in a future refactor.
///
/// For now, the provider covers the media-state axis only. The screen calls
/// [deriveRoomRenderState] with the live [hasVideoStreams] value to produce
/// the final composite state. This ensures:
/// 1. Health derivation lives outside the widget.
/// 2. Stream presence is still read from its authoritative source.
/// 3. The provider is still testable for the media-state axis alone.
final roomRenderStateProvider = Provider.family
    .autoDispose<RoomRenderState, _RoomRenderStateArgs>((ref, args) {
  final mediaState = ref.watch(
    liveRoomMediaControllerProvider(args.roomId),
  );
  return deriveRoomRenderState(
    mediaState: mediaState,
    hasRtcService: args.hasRtcService,
    hasVideoStreams: args.hasVideoStreams,
  );
});

/// Arguments for [roomRenderStateProvider].
///
/// Immutable value class used as the family key.
class _RoomRenderStateArgs {
  const _RoomRenderStateArgs({
    required this.roomId,
    required this.hasRtcService,
    required this.hasVideoStreams,
  });

  final String roomId;
  final bool hasRtcService;
  final bool hasVideoStreams;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RoomRenderStateArgs &&
          roomId == other.roomId &&
          hasRtcService == other.hasRtcService &&
          hasVideoStreams == other.hasVideoStreams;

  @override
  int get hashCode => Object.hash(roomId, hasRtcService, hasVideoStreams);
}
