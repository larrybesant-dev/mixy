import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' show sin, pi;

import '../../../core/theme.dart';
import '../../../presentation/providers/user_provider.dart';
import '../providers/rtc_service_provider.dart';
import '../room_controller.dart';

import '../providers/camera_wall_provider.dart';

class CameraWallRemoteTileData {
  const CameraWallRemoteTileData({
    required this.uid,
    this.userId,
    required this.label,
    required this.canView,
    required this.isSpeaking,
    this.hasMic = false,
    this.viewerCount,
    this.avatarUrl,
  });

  final int uid;

  /// Firestore user ID for this remote participant (null if mapping unknown).
  final String? userId;
  final String label;
  final bool canView;
  final bool isSpeaking;

  /// True when this participant is the current mic holder (role == 'stage').
  final bool hasMic;

  /// Optional viewer count shown as a badge on the tile (null = hidden).
  final int? viewerCount;

  /// Profile photo URL shown in the cam area when camera is off or access is locked.
  final String? avatarUrl;
}

class CameraWall extends ConsumerStatefulWidget {
  const CameraWall({
    super.key,
    required this.roomId,
    required this.localLabel,
    required this.localSpeaking,
    this.showLocalTile = true,
    this.localHasMic = false,
    required this.localTile,
    required this.remoteTiles,
    required this.remoteTileBuilder,
    required this.onSubscriptionPlanChanged,
    required this.roomName,
    this.maxMainGridRemoteTiles = 8,
    this.overflowPageSize = 6,
    this.onDetachLocal,
    this.onDetachRemote,
    this.localAvatarUrl,
    this.localViewerCount,
    this.isHost = false,
    this.onDropUser,
    this.onMuteUser,
    this.spotlightUserId,
  });

  final String roomId;
  final String localLabel;
  final bool localSpeaking;

  /// Whether the local user's camera is on. If false, the local tile is hidden.
  final bool showLocalTile;

  /// True when the local user is the current mic holder (role == 'stage').
  final bool localHasMic;
  final Widget localTile;
  final List<CameraWallRemoteTileData> remoteTiles;
  final Widget Function(CameraWallRemoteTileData tile) remoteTileBuilder;
  final void Function(bool isLocalHighQuality, Set<int> highQualityUids, Set<int> lowQualityUids)
  onSubscriptionPlanChanged;
  final String roomName;
  final int maxMainGridRemoteTiles;
  final int overflowPageSize;

  /// Called when the user clicks "detach" on the local cam tile.
  final VoidCallback? onDetachLocal;

  /// Called when the user clicks "detach" on a remote cam tile.
  final void Function(CameraWallRemoteTileData tile)? onDetachRemote;

  /// Profile photo URL for the local user (shown when camera is off).
  final String? localAvatarUrl;

  /// Viewer count badge for the local camera tile.
  final int? localViewerCount;

  final bool isHost;
  final void Function(String userId)? onDropUser;
  final void Function(String userId, bool mute)? onMuteUser;

  /// Current user pinned in spotlight (escalated to high quality).
  final String? spotlightUserId;

  @override
  ConsumerState<CameraWall> createState() => _CameraWallState();
}

class _CameraWallState extends ConsumerState<CameraWall> {
  // Cached state to optimize and govern WebRTC quality changes
  bool? _lastIsLocalHighQuality;
  Set<int>? _lastHighQualityUids;
  Set<int>? _lastLowQualityUids;

  bool _setsEqual(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  void _checkAndNotifySubscriptionPlan(
    bool isLocalHighQuality,
    Set<int> highQualityUids,
    Set<int> lowQualityUids,
  ) {
    final bool changed = _lastIsLocalHighQuality != isLocalHighQuality ||
        _lastHighQualityUids == null ||
        _lastLowQualityUids == null ||
        !_setsEqual(_lastHighQualityUids!, highQualityUids) ||
        !_setsEqual(_lastLowQualityUids!, lowQualityUids);

    if (changed) {
      _lastIsLocalHighQuality = isLocalHighQuality;
      _lastHighQualityUids = highQualityUids;
      _lastLowQualityUids = lowQualityUids;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSubscriptionPlanChanged(isLocalHighQuality, highQualityUids, lowQualityUids);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final npSurfaceLow = VelvetNoir.surfaceLow;
    const double maxTileH = 280.0;
    const double mobileH = 160.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Strict clamps on constraints to avoid infinite or zero/negative dimensions throwing rendering exceptions
        final double safeMaxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
        final isDesktop = safeMaxWidth >= 600;

        final mainGridRemoteLimit = isDesktop
            ? widget.maxMainGridRemoteTiles + 4
            : widget.maxMainGridRemoteTiles;
        final effectiveOverflowPageSize = isDesktop
            ? widget.overflowPageSize * 2
            : widget.overflowPageSize;

        final viewableRemoteTiles = widget.remoteTiles
            .where((tile) => tile.canView)
            .toList(growable: false);
        final blockedRemoteTiles = widget.remoteTiles
            .where((tile) => !tile.canView)
            .toList(growable: false);
        final mainGridRemoteTiles = viewableRemoteTiles
            .take(mainGridRemoteLimit)
            .toList(growable: false);
        final overflowTiles = <CameraWallRemoteTileData>[
          ...viewableRemoteTiles.skip(mainGridRemoteLimit),
          ...blockedRemoteTiles,
        ];

        final overflowPageCount = overflowTiles.isEmpty
            ? 0
            : ((overflowTiles.length - 1) ~/ effectiveOverflowPageSize) + 1;
        final rawOverflowPage = ref.watch(
          cameraWallOverflowPageProvider(widget.roomId),
        );
        final overflowPage = overflowPageCount == 0
            ? 0
            : rawOverflowPage.clamp(0, overflowPageCount - 1);
        if (overflowPage != rawOverflowPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(cameraWallOverflowPageProvider(widget.roomId).notifier).state =
                  overflowPage;
            }
          });
        }

        final overflowStart = overflowPage * effectiveOverflowPageSize;
        final overflowEnd = overflowPageCount == 0
            ? 0
            : (overflowStart + effectiveOverflowPageSize > overflowTiles.length
                  ? overflowTiles.length
                  : overflowStart + effectiveOverflowPageSize);
        final visibleOverflowTiles = overflowTiles.sublist(
          overflowStart,
          overflowEnd,
        );

        // ── BANDWIDTH GOVERNOR (Dual-Stream Architecture) ───────────────────
        final speakingInMainGrid = mainGridRemoteTiles.where((tile) => tile.isSpeaking).toList();
        final pinnedInMainGrid = mainGridRemoteTiles.where((tile) => tile.userId == widget.spotlightUserId).toList();
        
        final currentUserId = ref.watch(userProvider)?.id;
        final isLocalPinned = widget.spotlightUserId != null && currentUserId == widget.spotlightUserId;
        final bool isLocalHighQuality;
        
        final Set<int> highQualityUids;
        if (isLocalPinned) {
          isLocalHighQuality = true;
          highQualityUids = const {};
        } else if (pinnedInMainGrid.isNotEmpty) {
          isLocalHighQuality = false;
          highQualityUids = pinnedInMainGrid.map((tile) => tile.uid).toSet();
        } else if (widget.localSpeaking && widget.showLocalTile) {
          isLocalHighQuality = true;
          highQualityUids = const {};
        } else if (speakingInMainGrid.isNotEmpty) {
          isLocalHighQuality = false;
          highQualityUids = speakingInMainGrid.map((tile) => tile.uid).toSet();
        } else if (widget.showLocalTile) {
          isLocalHighQuality = true;
          highQualityUids = const {};
        } else if (mainGridRemoteTiles.isNotEmpty) {
          isLocalHighQuality = false;
          highQualityUids = {mainGridRemoteTiles.first.uid};
        } else {
          isLocalHighQuality = true;
          highQualityUids = const {};
        }

        final lowQualityUids = {
          ...mainGridRemoteTiles
              .where((tile) => !highQualityUids.contains(tile.uid))
              .map((tile) => tile.uid),
          ...visibleOverflowTiles
              .where((tile) => tile.canView)
              .map((tile) => tile.uid),
        };

        // Governs quality subscription plan changes and cuts layout circular dependencies
        _checkAndNotifySubscriptionPlan(isLocalHighQuality, highQualityUids, lowQualityUids);

        // Collect speaking names for compact status display
        final speakingNames = <String>[
          if (widget.localSpeaking && widget.showLocalTile) widget.localLabel,
          ...mainGridRemoteTiles.where((t) => t.isSpeaking).map((t) => t.label),
        ];

        // Ensure negative numbers can't cause layout overflow
        const double spacing = 8;
        const double headerH = 24;
        final int estimatedTileCount = (widget.showLocalTile ? 1 : 0) + mainGridRemoteTiles.length;
        final int estimatedCrossAxisCount = (isDesktop
            ? (estimatedTileCount <= 1
                  ? 1
                  : estimatedTileCount <= 4
                  ? 2
                  : estimatedTileCount <= 9
                  ? 3
                  : 4)
            : (estimatedTileCount <= 2
                  ? 1
                  : estimatedTileCount <= 4
                  ? 2
                  : 3)).clamp(1, 10);
        final double estimatedWidth = (safeMaxWidth - 20).clamp(10.0, double.infinity);
        final double effectiveTileW = (estimatedCrossAxisCount > 0)
            ? (estimatedWidth / estimatedCrossAxisCount - (spacing * (estimatedCrossAxisCount - 1) / estimatedCrossAxisCount)).clamp(40.0, 1200.0)
            : 120.0;
        final double tileHeight = (effectiveTileW.isFinite && effectiveTileW > 0)
            ? (effectiveTileW * (3 / 4) + headerH).clamp(100.0, maxTileH)
            : 120.0;

        final mainGridTiles = <Widget>[
          if (widget.showLocalTile)
            _ResizableTile(
              key: ValueKey<String>('local_tile_${widget.roomId}'),
              defaultWidth: effectiveTileW,
              defaultHeight: tileHeight,
              child: _CameraWallTileFrame(
                roomId: widget.roomId,
                label: widget.localLabel,
                speaking: widget.localSpeaking,
                hasMic: widget.localHasMic,
                compact: false,
                onDetach: widget.onDetachLocal,
                viewerCount: widget.localViewerCount,
                child: widget.localTile,
              ),
            ),
          ...mainGridRemoteTiles.map(
            (tile) {
              final frame = _ResizableTile(
                key: ValueKey<int>(tile.uid),
                defaultWidth: effectiveTileW,
                defaultHeight: tileHeight,
                child: _CameraWallTileFrame(
                  roomId: widget.roomId,
                  label: tile.label,
                  speaking: tile.isSpeaking,
                  hasMic: tile.hasMic,
                  compact: false,
                  viewerCount: tile.viewerCount,
                  onDetach: widget.onDetachRemote == null
                      ? null
                      : () => widget.onDetachRemote!(tile),
                  showAdminTools: widget.isHost && tile.userId != null,
                  onDrop: tile.userId == null ? null : () => widget.onDropUser?.call(tile.userId!),
                  onMute: tile.userId == null ? null : (m) => widget.onMuteUser?.call(tile.userId!, m),
                  isPinned: tile.userId == widget.spotlightUserId,
                  child: widget.remoteTileBuilder(tile),
                ),
              );

              return GestureDetector(
                key: ValueKey<String>('gesture_${tile.uid}'),
                onDoubleTap: () {
                  if (tile.userId != null) {
                    ref.read(roomControllerProvider(widget.roomId).notifier).setSpotlightUser(
                      widget.spotlightUserId == tile.userId ? null : tile.userId
                    );
                  }
                },
                child: frame,
              );
            },
          ),
        ];

        final tileCount = mainGridTiles.length;
        final crossAxisCount = (isDesktop
            ? (tileCount <= 1
                  ? 1
                  : tileCount <= 4
                  ? 2
                  : tileCount <= 9
                  ? 3
                  : 4)
            : (tileCount <= 2
                  ? 1
                  : tileCount <= 4
                  ? 2
                  : 3)).clamp(1, 10);
        final int rows = (crossAxisCount > 0)
            ? ((tileCount == 0 ? 1 : tileCount) / crossAxisCount).ceil()
            : 1;

        return ColoredBox(
          color: npSurfaceLow,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overflowTiles.isNotEmpty) ...[
                  Row(
                    children: [
                      const Spacer(),
                      if (overflowPageCount > 1)
                        Text(
                          'Page ${overflowPage + 1} of $overflowPageCount',
                          style: const TextStyle(
                            color: Color(0xFFB09080),
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Previous cam page',
                        visualDensity: VisualDensity.compact,
                        onPressed: overflowPage > 0
                            ? () {
                                ref
                                        .read(
                                          cameraWallOverflowPageProvider(
                                            widget.roomId,
                                          ).notifier,
                                        )
                                        .state =
                                    overflowPage - 1;
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: 'Next cam page',
                        visualDensity: VisualDensity.compact,
                        onPressed: overflowPage < overflowPageCount - 1
                            ? () {
                                ref
                                        .read(
                                          cameraWallOverflowPageProvider(
                                            widget.roomId,
                                          ).notifier,
                                        )
                                        .state =
                                    overflowPage + 1;
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (speakingNames.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: VelvetNoir.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: VelvetNoir.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: VelvetNoir.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Talking: ',
                          style: TextStyle(
                            color: VelvetNoir.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            speakingNames.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isDesktop)
                  LayoutBuilder(
                    builder: (context, lbConstraints) {
                      final sideW = overflowTiles.isNotEmpty ? 218.0 : 0.0;
                      final gridW = (lbConstraints.maxWidth - sideW).clamp(
                        80.0,
                        double.infinity,
                      );
                      final double desktopEffectiveTileW = (crossAxisCount > 0)
                          ? (tileCount <= 1
                              ? (gridW / crossAxisCount).clamp(80.0, 800.0)
                              : (gridW - spacing * (crossAxisCount - 1)) /
                                    crossAxisCount)
                          : 80.0;
                      final desktopTileHeight = (desktopEffectiveTileW.isFinite && desktopEffectiveTileW > 0)
                          ? (desktopEffectiveTileW * (3 / 4) + headerH).clamp(100.0, maxTileH)
                          : 120.0;
                      final mainGridHeight =
                          (rows * (desktopTileHeight + spacing) - spacing).clamp(0.0, double.infinity);

                      Widget grid = Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.showLocalTile)
                            _ResizableTile(
                              key: const ValueKey('rtile_local'),
                              defaultWidth: desktopEffectiveTileW,
                              defaultHeight: desktopTileHeight,
                              child: _CameraWallTileFrame(
                                roomId: widget.roomId,
                                label: widget.localLabel,
                                speaking: widget.localSpeaking,
                                hasMic: widget.localHasMic,
                                compact: false,
                                onDetach: widget.onDetachLocal,
                                viewerCount: widget.localViewerCount,
                                child: widget.localTile,
                              ),
                            ),
                          ...mainGridRemoteTiles.map(
                            (tile) => _ResizableTile(
                              key: ValueKey('rtile_${tile.uid}'),
                              defaultWidth: desktopEffectiveTileW,
                              defaultHeight: desktopTileHeight,
                              child: _CameraWallTileFrame(
                                roomId: widget.roomId,
                                label: tile.label,
                                speaking: tile.isSpeaking,
                                hasMic: tile.hasMic,
                                compact: false,
                                viewerCount: tile.viewerCount,
                                onDetach: widget.onDetachRemote == null
                                    ? null
                                    : () => widget.onDetachRemote!(tile),
                                child: widget.remoteTileBuilder(tile),
                              ),
                            ),
                          ),
                        ],
                      );
                      if (tileCount <= 1) {
                        grid = Align(
                          alignment: Alignment.center,
                          child: SizedBox(width: desktopEffectiveTileW, child: grid),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: grid),
                          if (overflowTiles.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 208,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: VelvetNoir.surfaceLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: VelvetNoir.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Extra Windows',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: (mainGridHeight - 24).clamp(
                                          100.0,
                                          1200.0,
                                        ),
                                        child: GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                mainAxisSpacing: 8,
                                                crossAxisSpacing: 8,
                                                childAspectRatio: 1,
                                              ),
                                          itemCount:
                                              visibleOverflowTiles.length,
                                          itemBuilder: (context, index) {
                                            final tile =
                                                visibleOverflowTiles[index];
                                            return _CameraWallTileFrame(
                                              roomId: widget.roomId,
                                              label: tile.label,
                                              speaking: tile.isSpeaking,
                                              hasMic: tile.hasMic,
                                              compact: true,
                                              onDetach: widget.onDetachRemote == null
                                                  ? null
                                                  : () => widget.onDetachRemote!(tile),
                                              child: widget.remoteTileBuilder(tile),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  )
                else ...[
                  SizedBox(
                    height: (rows * (mobileH + spacing) - spacing).clamp(0.0, double.infinity),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: mainGridTiles.length,
                      itemBuilder: (context, index) => mainGridTiles[index],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (overflowTiles.isNotEmpty)
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: visibleOverflowTiles.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final tile = visibleOverflowTiles[index];
                          return SizedBox(
                            width: 132,
                            child: _CameraWallTileFrame(
                              roomId: widget.roomId,
                              label: tile.label,
                              speaking: tile.isSpeaking,
                              hasMic: tile.hasMic,
                              compact: true,
                              onDetach: widget.onDetachRemote == null
                                  ? null
                                  : () => widget.onDetachRemote!(tile),
                              child: widget.remoteTileBuilder(tile),
                            ),
                          );
                        },
                      ),
                    )
                  else if (widget.remoteTiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Waiting for others to join video...',
                        style: TextStyle(
                          color: Color(0xFFB09080),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CameraWallTileFrame extends StatefulWidget {
  const _CameraWallTileFrame({
    required this.roomId,
    required this.label,
    required this.speaking,
    this.hasMic = false,
    required this.compact,
    required this.child,
    this.onDetach,
    this.viewerCount,
    this.showAdminTools = false,
    this.onDrop,
    this.onMute,
    this.isPinned = false,
  });

  final String roomId;
  final String label;
  final bool speaking;

  /// True when this participant is the current mic holder.
  final bool hasMic;
  final bool compact;
  final Widget child;

  /// If non-null, a pop-out button is shown in the tile header.
  final VoidCallback? onDetach;

  /// If non-null and > 0, a viewer count badge is shown on the tile.
  final int? viewerCount;

  final bool showAdminTools;
  final VoidCallback? onDrop;
  final void Function(bool mute)? onMute;

  final bool isPinned;

  @override
  State<_CameraWallTileFrame> createState() => _CameraWallTileFrameState();
}

class _CameraWallTileFrameState extends State<_CameraWallTileFrame> with TickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // ONLY repeat the controller if the widget is actively speaking, preventing continuous idle frame builds on inactive widgets
    if (widget.speaking) {
      _pulseCtrl.repeat(reverse: true);
    }
    
    // Gold shimmer animation for host frame (3s cycle)
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.hasMic) {
      _shimmerCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(_CameraWallTileFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speaking != oldWidget.speaking) {
      if (widget.speaking) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.value = 0.0;
      }
    }
    if (widget.hasMic != oldWidget.hasMic) {
      if (widget.hasMic) {
        _shimmerCtrl.repeat();
      } else {
        _shimmerCtrl.stop();
        _shimmerCtrl.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const npSurfaceContainer = Color(0xFF0B0B0B); // Jet Black
    const npSurfaceHigh = Color(0xFF1C1617); // elevated surface
    final npGold = VelvetNoir.gold; // Gold — host/mic holder
    final npCyan = VelvetNoir.primary; // Cyan — speaking glow
    const npOnVariant = Color(0xFFAD9585); // muted cream
    const npGoldBright = Color(0xFFFFD700); // Bright gold for shimmer

    final radius = widget.compact ? 8.0 : 10.0;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _shimmerCtrl]),
      builder: (context, child) {
        final pulseValue = widget.speaking ? _pulseCtrl.value : 0.0;
        // Shimmer: oscillate between gold and bright gold
        final shimmerValue = widget.hasMic ? _shimmerCtrl.value : 0.0;
        final shimmerColor = Color.lerp(npGold, npGoldBright, (sin(shimmerValue * 2 * pi) + 1) / 2);
        
        // Pin (spotlight) gets primary cyan; Host (hasMic) gets shimmering gold frame; speaking gets neon cyan glow; else subtle
        final Color borderColor = widget.isPinned
            ? VelvetNoir.primary
            : widget.hasMic
            ? shimmerColor ?? npGold
            : widget.speaking
            ? npCyan
            : const Color(0x20D4AF37);
            
        final double borderWidth = (widget.isPinned || widget.hasMic || widget.speaking) ? 2.0 : 1.0;
        
        final glowShadow = widget.isPinned
            ? [
                BoxShadow(
                  color: VelvetNoir.primary.withValues(alpha: 0.4 + (pulseValue * 0.2)),
                  blurRadius: 16 + (pulseValue * 8),
                  spreadRadius: 2 + (pulseValue * 2),
                ),
              ]
            : widget.hasMic
            ? [
                // Primary gold shimmer glow
                BoxShadow(
                  color: (shimmerColor ?? npGold).withValues(alpha: 0.3 + (shimmerValue * 0.1)),
                  blurRadius: 14 + (shimmerValue * 4),
                  spreadRadius: 2 + (shimmerValue * 1),
                ),
                // Secondary layer: subtle wine-red accent when speaking
                if (widget.speaking)
                  BoxShadow(
                    color: const Color(0xFF9B2535).withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
              ]
            : widget.speaking
            ? [
                // Primary cyan speaking glow
                BoxShadow(
                  color: npCyan.withValues(alpha: 0.3 + (pulseValue * 0.3)),
                  blurRadius: 10 + (pulseValue * 10),
                  spreadRadius: 1 + (pulseValue * 2),
                ),
                // Secondary layer: wine-red outer glow for luxury effect
                BoxShadow(
                  color: const Color(0xFF9B2535).withValues(alpha: 0.15 + (pulseValue * 0.15)),
                  blurRadius: 6 + (pulseValue * 4),
                  spreadRadius: 2,
                ),
              ]
            : const <BoxShadow>[];

        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool showHeader = constraints.maxHeight > 40;
              final double effectiveHeaderH = widget.compact ? 20 : 24;

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: npSurfaceContainer,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: glowShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Column(
                    children: [
                      if (showHeader)
                        Container(
                          height: effectiveHeaderH,
                          color: npSurfaceHigh,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: widget.isPinned
                                      ? VelvetNoir.primary
                                      : widget.hasMic
                                      ? npGold
                                      : widget.speaking
                                      ? npCyan
                                      : npOnVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (widget.isPinned) ...[
                                const Icon(
                                  Icons.push_pin_rounded,
                                  size: 10,
                                  color: VelvetNoir.primary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (widget.onDetach != null && (_hovered || widget.compact))
                                _TileActionButton(
                                  tooltip: 'Detach window',
                                  icon: Icons.open_in_new,
                                  onTap: widget.onDetach!,
                                ),
                              if (widget.showAdminTools) ...[
                                _TileActionButton(
                                  tooltip: 'Mute user',
                                  icon: Icons.mic_off_rounded,
                                  onTap: () => widget.onMute?.call(true),
                                  color: Colors.orange,
                                ),
                                _TileActionButton(
                                  tooltip: 'Drop from mic',
                                  icon: Icons.arrow_downward_rounded,
                                  onTap: widget.onDrop!,
                                  color: Colors.redAccent,
                                ),
                              ],
                            ],
                          ),
                        ),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: const Color(0xFF0D0A0C),
                              child: widget.child,
                            ),
                            if (widget.hasMic)
                              Positioned(
                                left: 5,
                                bottom: 8,
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final rtc = ref.watch(rtcServiceProvider(widget.roomId));
                                    final audioLevel = widget.label == 'You' 
                                      ? (rtc?.localAudioLevel ?? 0.0)
                                      : (rtc?.remoteAudioLevelForUid(rtc.remoteUids.firstWhere((id) => true, orElse: () => -1)) ?? 0.0);
                                    return _SoundWaveEq(active: widget.hasMic, audioLevel: audioLevel);
                                  }
                                ),
                              ),
                            if (widget.hasMic)
                              Positioned(
                                right: 5,
                                bottom: 8,
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final rtc = ref.watch(rtcServiceProvider(widget.roomId));
                                    final audioLevel = widget.label == 'You' 
                                      ? (rtc?.localAudioLevel ?? 0.0)
                                      : (rtc?.remoteAudioLevelForUid(rtc.remoteUids.firstWhere((id) => true, orElse: () => -1)) ?? 0.0);
                                    return _SoundWaveEq(active: widget.hasMic, audioLevel: audioLevel);
                                  }
                                ),
                              ),
                            if (widget.viewerCount != null && widget.viewerCount! > 0)
                              Positioned(
                                right: widget.speaking ? 36 : 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(160),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.visibility,
                                        color: VelvetNoir.secondary,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${widget.viewerCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    );
  }
}

/// Animated equalizer bars shown beside the cam while a participant is speaking.
class _SoundWaveEq extends StatefulWidget {
  const _SoundWaveEq({required this.active, this.audioLevel = 0.0});
  final bool active;
  final double audioLevel;

  @override
  State<_SoundWaveEq> createState() => _SoundWaveEqState();
}

class _SoundWaveEqState extends State<_SoundWaveEq>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Each bar has a different amplitude and phase within the animation cycle.
  static const _barMaxH = [10.0, 22.0, 15.0, 28.0];
  static const _intervals = [
    [0.00, 0.55],
    [0.15, 0.70],
    [0.30, 0.85],
    [0.45, 1.00],
  ];

  late final List<Animation<double>> _barAnims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnims = List.generate(4, (i) {
      return Tween<double>(begin: 3.0, end: _barMaxH[i]).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            _intervals[i][0],
            _intervals[i][1],
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_SoundWaveEq old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _ctrl.animateTo(0.0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            // Scale bar height by audio energy (0.0 - 1.0)
            final double energy = (widget.audioLevel.isFinite) ? widget.audioLevel.clamp(0.0, 1.0) : 0.0;
            final energyScale = 0.3 + (energy * 0.7);
            final h = _barAnims[i].value * energyScale;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 3,
                height: h,
                decoration: BoxDecoration(
                  color: VelvetNoir.secondary.withValues(
                    alpha: widget.active ? 0.85 : 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _TileActionButton extends StatelessWidget {
  const _TileActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const npOnVariant = Color(0xFFAD9585);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(
            icon,
            size: 14,
            color: color ?? npOnVariant,
          ),
        ),
      ),
    );
  }
}

class _ResizableTile extends StatefulWidget {
  const _ResizableTile({
    super.key,
    required this.defaultWidth,
    required this.defaultHeight,
    required this.child,
  });

  final double defaultWidth;
  final double defaultHeight;
  final Widget child;

  @override
  State<_ResizableTile> createState() => _ResizableTileState();
}

class _ResizableTileState extends State<_ResizableTile> {
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    _width = widget.defaultWidth;
    _height = widget.defaultHeight;
  }

  @override
  void didUpdateWidget(_ResizableTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Explicit didUpdateWidget handler to correctly update dimensions on layout adjustments (e.g. participant count changes)
    if (widget.defaultWidth != oldWidget.defaultWidth ||
        widget.defaultHeight != oldWidget.defaultHeight) {
      _width = widget.defaultWidth;
      _height = widget.defaultHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                setState(() {
                  _width = (_width + details.delta.dx).clamp(120.0, 640.0);
                  _height = (_height + details.delta.dy).clamp(100.0, 480.0);
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0x50D4A853),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: const Icon(
                    Icons.south_east,
                    size: 9,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



