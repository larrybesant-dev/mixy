import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/rtc_service_provider.dart';

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

class CameraWall extends ConsumerWidget {
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
  final void Function(Set<int> highQualityUids, Set<int> lowQualityUids)
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final npSurfaceLow = Theme.of(context).colorScheme.surfaceContainerHighest;
    const double maxTileH = 280.0;
    const double mobileH = 160.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final mainGridRemoteLimit = isDesktop
            ? maxMainGridRemoteTiles + 4
            : maxMainGridRemoteTiles;
        final effectiveOverflowPageSize = isDesktop
            ? overflowPageSize * 2
            : overflowPageSize;

        final viewableRemoteTiles = remoteTiles
            .where((tile) => tile.canView)
            .toList(growable: false);
        final blockedRemoteTiles = remoteTiles
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
          cameraWallOverflowPageProvider(roomId),
        );
        final overflowPage = overflowPageCount == 0
            ? 0
            : rawOverflowPage.clamp(0, overflowPageCount - 1);
        if (overflowPage != rawOverflowPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(cameraWallOverflowPageProvider(roomId).notifier).state =
                overflowPage;
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

        final highQualityUids = mainGridRemoteTiles
            .map((tile) => tile.uid)
            .toSet();
        final lowQualityUids = visibleOverflowTiles
            .where((tile) => tile.canView)
            .map((tile) => tile.uid)
            .toSet();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onSubscriptionPlanChanged(highQualityUids, lowQualityUids);
        });

        // Collect speaking names for the compact names strip.
        // Tiles stay in the main grid — the cyan glow border on each tile already
        // provides per-tile speaking feedback.  Physically lifting tiles into a
        // separate section changes tileCount/crossAxisCount on every VAD event,
        // causing the entire grid to reflow and tiles to jump positions.
        final speakingNames = <String>[
          if (localSpeaking && showLocalTile) localLabel,
          ...mainGridRemoteTiles.where((t) => t.isSpeaking).map((t) => t.label),
        ];

        // Estimate tile dimensions before building tiles (avoids circular dependency).
        // Initial estimate based on constraint width.
        const double spacing = 8;
        const double headerH = 24;
        final int estimatedTileCount = (showLocalTile ? 1 : 0) + mainGridRemoteTiles.length;
        final int estimatedCrossAxisCount = isDesktop
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
                  : 3);
        final double estimatedWidth = constraints.maxWidth - 20;
        final double effectiveTileW = estimatedWidth / estimatedCrossAxisCount - (spacing * (estimatedCrossAxisCount - 1) / estimatedCrossAxisCount);
        final double tileHeight = effectiveTileW * (3 / 4) + headerH;

        final mainGridTiles = <Widget>[
          if (showLocalTile)
            _CameraWallTileFrame(
              roomId: roomId,
              label: localLabel,
              speaking: localSpeaking,
              hasMic: localHasMic,
              compact: false,
              onDetach: onDetachLocal,
              viewerCount: localViewerCount,
              child: localTile,
            ),
          ...mainGridRemoteTiles.map(
            (tile) => _ResizableTile(
              key: ValueKey('rtile_${tile.uid}'),
              defaultWidth: effectiveTileW,
              defaultHeight: tileHeight,
              child: _CameraWallTileFrame(
                roomId: roomId,
                label: tile.label,
                speaking: tile.isSpeaking,
                hasMic: tile.hasMic,
                compact: false,
                viewerCount: tile.viewerCount,
                onDetach: onDetachRemote == null
                    ? null
                    : () => onDetachRemote!(tile),
                showAdminTools: isHost && tile.userId != null,
                onDrop: tile.userId == null ? null : () => onDropUser?.call(tile.userId!),
                onMute: tile.userId == null ? null : (m) => onMuteUser?.call(tile.userId!, m),
                child: remoteTileBuilder(tile),
              ),
            ),
          ),
        ];

        final tileCount = mainGridTiles.length;
        final crossAxisCount = isDesktop
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
                  : 3);
        final int rows = ((tileCount == 0 ? 1 : tileCount) / crossAxisCount)
            .ceil();

        return ColoredBox(
          color: npSurfaceLow,
          child: Padding(
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
                                            roomId,
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
                                            roomId,
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
                // ── Compact "Talking Now" names strip ───────────────────
                // Shows who is speaking without moving any tiles.  Tiles stay
                // in their stable grid positions; the cyan border/glow on each
                // tile already provides visual speaking feedback in-place.
                if (speakingNames.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161012),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0x409B2535), // wine red @ 25%
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF9B2535), // wine red live dot
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Talking: ',
                          style: TextStyle(
                            color: Color(0xFFD4AF37), // gold label
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
                      // Overflow sidebar takes 208 + 10px; ignore if not present.
                      final sideW = overflowTiles.isNotEmpty ? 218.0 : 0.0;
                      final gridW = (lbConstraints.maxWidth - sideW).clamp(
                        80.0,
                        double.infinity,
                      );
                      // For a single tile, cap its width so it doesn't span the
                      // full ~800 px panel — makes the tile a reasonable size and
                      // leaves no wasted space beside it.
                      final effectiveTileW = tileCount <= 1
                          ? (gridW / crossAxisCount).clamp(80.0, 800.0)
                          : (gridW - spacing * (crossAxisCount - 1)) /
                                crossAxisCount;
                      // Use 4:3 ratio for tile height — matches typical webcam output so
                      // RTCVideoViewObjectFitContain fills the frame with minimal black bars.
                      final tileHeight = (effectiveTileW * (3 / 4) + headerH)
                          .clamp(120.0, maxTileH);
                      final mainGridHeight =
                          rows * (tileHeight + spacing) - spacing;
                      // For a single centered tile, wrap the grid in a centered box.
                      Widget grid = Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (showLocalTile)
                            _ResizableTile(
                              key: const ValueKey('rtile_local'),
                              defaultWidth: effectiveTileW,
                              defaultHeight: tileHeight,
                              child: _CameraWallTileFrame(
                                roomId: roomId,
                                label: localLabel,
                                speaking: localSpeaking,
                                hasMic: localHasMic,
                                compact: false,
                                onDetach: onDetachLocal,
                                viewerCount: localViewerCount,
                                child: localTile,
                              ),
                            ),
                          ...mainGridRemoteTiles.map(
                            (tile) => _ResizableTile(
                              key: ValueKey('rtile_${tile.uid}'),
                              defaultWidth: effectiveTileW,
                              defaultHeight: tileHeight,
                              child: _CameraWallTileFrame(
                                roomId: roomId,
                                label: tile.label,
                                speaking: tile.isSpeaking,
                                hasMic: tile.hasMic,
                                compact: false,
                                viewerCount: tile.viewerCount,
                                onDetach: onDetachRemote == null
                                    ? null
                                    : () => onDetachRemote!(tile),
                                child: remoteTileBuilder(tile),
                              ),
                            ),
                          ),
                        ],
                      );
                      if (tileCount <= 1) {
                        grid = Align(
                          alignment: Alignment.center,
                          child: SizedBox(width: effectiveTileW, child: grid),
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
                                  color: const Color(0xFF161A21),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0x1A73757D),
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
                                              roomId: roomId,
                                              label: tile.label,
                                              speaking: tile.isSpeaking,
                                              hasMic: tile.hasMic,
                                              compact: true,
                                              onDetach: onDetachRemote == null
                                                  ? null
                                                  : () => onDetachRemote!(tile),
                                              child: remoteTileBuilder(tile),
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
                    height: rows * (mobileH + spacing) - spacing,
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
                              roomId: roomId,
                              label: tile.label,
                              speaking: tile.isSpeaking,
                              hasMic: tile.hasMic,
                              compact: true,
                              onDetach: onDetachRemote == null
                                  ? null
                                  : () => onDetachRemote!(tile),
                              child: remoteTileBuilder(tile),
                            ),
                          );
                        },
                      ),
                    )
                  else if (remoteTiles.isEmpty)
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
  });

  final String roomId;
  final String label;
  final bool speaking;

  /// True when this participant is the current mic holder. EQ bars are only
  /// shown for the mic holder, not for everyone who is speaking.
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

  @override
  State<_CameraWallTileFrame> createState() => _CameraWallTileFrameState();
}

class _CameraWallTileFrameState extends State<_CameraWallTileFrame> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const npSurfaceContainer = Color(0xFF0B0B0B); // Jet Black
    const npSurfaceHigh = Color(0xFF1C1617); // elevated surface
    const npGold = Color(0xFFD4AF37); // Gold — host/mic holder
    const npWineRed = Color(0xFF9B2535); // Wine Red — speaking glow
    const npOnVariant = Color(0xFFAD9585); // muted cream

    final radius = widget.compact ? 8.0 : 10.0;
    // Host (hasMic) gets gold frame; speaking gets wine-red glow; else subtle
    final Color borderColor = widget.hasMic
        ? npGold
        : widget.speaking
        ? npWineRed
        : const Color(0x20D4AF37);
    final double borderWidth = (widget.hasMic || widget.speaking) ? 2.0 : 1.0;
    final glowShadow = widget.hasMic
        ? [
            BoxShadow(
              color: npGold.withAlpha(70),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ]
        : widget.speaking
        ? [
            BoxShadow(
              color: npWineRed.withAlpha(80),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ]
        : const <BoxShadow>[];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
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
              Container(
                height: widget.compact ? 20 : 24,
                color: npSurfaceHigh,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.hasMic
                            ? npGold
                            : widget.speaking
                            ? npWineRed
                            : npOnVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                    // Pop-out button: visible on hover (desktop) or always on mobile
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
                    // EQ sound-wave bars only on the mic holder
                    if (widget.hasMic)
                      Positioned(
                        left: 5,
                        bottom: 8,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final rtc = ref.watch(rtcServiceProvider(widget.roomId));
                            final audioLevel = widget.label == 'You' 
                              ? (rtc?.localAudioLevel ?? 0.0)
                              : (rtc?.remoteAudioLevelForUid(rtc.remoteUids.firstWhere((id) => true, orElse: () => -1)) ?? 0.0); // Simple fallback for now
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
                    // Viewer count badge (bottom-right corner, shifted left when speaking)
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
                                color: Color(0xFFC45E7A),
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
      ),
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
            final energyScale = 0.3 + (widget.audioLevel * 0.7);
            final h = _barAnims[i].value * energyScale;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 3,
                height: h,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFC45E7A,
                  ).withAlpha(widget.active ? 220 : 80),
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

// ---------------------------------------------------------------------------
// Resizable tile wrapper — drag the bottom-right handle to resize any cam tile.
// State is preserved across rebuilds via the widget's stable ValueKey.
// ---------------------------------------------------------------------------
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          // Drag this handle to resize the cam tile.
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
