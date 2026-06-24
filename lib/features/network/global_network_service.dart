/// Global Network Service
///
/// Manages multi-region routing, latency-adaptive video, global presence sync,
/// and cross-region room mirroring.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Geographic region
enum Region {
  usEast,
  usWest,
  euWest,
  euCentral,
  asiaPacific,
  asiaSouth,
  southAmerica,
  australia,
  africa,
}

/// Edge node status
enum NodeStatus {
  online,
  degraded,
  offline,
  maintenance,
}

/// Video quality tier
enum VideoQuality {
  low, // 240p
  medium, // 480p
  high, // 720p
  hd, // 1080p
  uhd, // 4K
}

/// Region information
class RegionInfo {
  final Region region;
  final String name;
  final String code;
  final double latitude;
  final double longitude;
  final List<String> edgeNodes;
  final bool isActive;
  final int currentLoad;
  final int maxCapacity;

  const RegionInfo({
    required this.region,
    required this.name,
    required this.code,
    required this.latitude,
    required this.longitude,
    this.edgeNodes = const [],
    this.isActive = true,
    this.currentLoad = 0,
    this.maxCapacity = 10000,
  });

  double get loadPercentage => maxCapacity > 0 ? currentLoad / maxCapacity : 0;

  factory RegionInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegionInfo(
      region: Region.values.firstWhere(
        (r) => r.name == data['region'],
        orElse: () => Region.usEast,
      ),
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      edgeNodes: List<String>.from(data['edgeNodes'] ?? []),
      isActive: data['isActive'] ?? true,
      currentLoad: data['currentLoad'] ?? 0,
      maxCapacity: data['maxCapacity'] ?? 10000,
    );
  }
}

/// User presence information
class UserPresence {
  final String oderId;
  final Region region;
  final String? currentRoom;
  final DateTime lastSeen;
  final bool isOnline;
  final String? edgeNode;
  final Map<String, dynamic> metadata;

  const UserPresence({
    required this.oderId,
    required this.region,
    this.currentRoom,
    required this.lastSeen,
    this.isOnline = false,
    this.edgeNode,
    this.metadata = const {},
  });

  factory UserPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPresence(
      oderId: doc.id,
      region: Region.values.firstWhere(
        (r) => r.name == data['region'],
        orElse: () => Region.usEast,
      ),
      currentRoom: data['currentRoom'],
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] ?? false,
      edgeNode: data['edgeNode'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'region': region.name,
        'currentRoom': currentRoom,
        'lastSeen': Timestamp.fromDate(lastSeen),
        'isOnline': isOnline,
        'edgeNode': edgeNode,
        'metadata': metadata,
      };
}

/// Room mirror for cross-region mirroring
class RoomMirror {
  final String mirrorId;
  final String sourceRoom;
  final Region sourceRegion;
  final Region targetRegion;
  final String targetEdgeNode;
  final DateTime createdAt;
  final int latencyMs;
  final bool isActive;

  const RoomMirror({
    required this.mirrorId,
    required this.sourceRoom,
    required this.sourceRegion,
    required this.targetRegion,
    required this.targetEdgeNode,
    required this.createdAt,
    this.latencyMs = 0,
    this.isActive = true,
  });

  factory RoomMirror.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomMirror(
      mirrorId: doc.id,
      sourceRoom: data['sourceRoom'] ?? '',
      sourceRegion: Region.values.firstWhere(
        (r) => r.name == data['sourceRegion'],
        orElse: () => Region.usEast,
      ),
      targetRegion: Region.values.firstWhere(
        (r) => r.name == data['targetRegion'],
        orElse: () => Region.usWest,
      ),
      targetEdgeNode: data['targetEdgeNode'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latencyMs: data['latencyMs'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sourceRoom': sourceRoom,
        'sourceRegion': sourceRegion.name,
        'targetRegion': targetRegion.name,
        'targetEdgeNode': targetEdgeNode,
        'createdAt': Timestamp.fromDate(createdAt),
        'latencyMs': latencyMs,
        'isActive': isActive,
      };
}

/// Latency measurement
class LatencyMeasurement {
  final Region region;
  final int latencyMs;
  final DateTime measuredAt;
  final double packetLoss;
  final double jitter;

  const LatencyMeasurement({
    required this.region,
    required this.latencyMs,
    required this.measuredAt,
    this.packetLoss = 0,
    this.jitter = 0,
  });
}

/// Global network service singleton
class GlobalNetworkService {
  static GlobalNetworkService? _instance;
  static GlobalNetworkService get instance =>
      _instance ??= GlobalNetworkService._();

  GlobalNetworkService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _regionsCollection =>
      _firestore.collection('regions');
  CollectionReference get _presenceCollection =>
      _firestore.collection('presence');
  CollectionReference get _mirrorsCollection =>
      _firestore.collection('room_mirrors');

  final StreamController<UserPresence> _presenceController =
      StreamController<UserPresence>.broadcast();
  final StreamController<LatencyMeasurement> _latencyController =
      StreamController<LatencyMeasurement>.broadcast();

  Stream<UserPresence> get presenceStream => _presenceController.stream;
  Stream<LatencyMeasurement> get latencyStream => _latencyController.stream;

  Region? _currentRegion;
  Region get currentRegion => _currentRegion ?? Region.usEast;

  final Map<Region, LatencyMeasurement> _latencyCache = {};
  Timer? _latencyMeasurementTimer;
  Timer? _presenceSyncTimer;

  // ============================================================
  // MULTI-REGION ROUTING
  // ============================================================

  /// Initialize multi-region routing
  Future<void> multiRegionRouting({String? userId}) async {
    debugPrint('ðŸŒ [GlobalNetwork] Initializing multi-region routing');

    // Detect best region based on latency
    final bestRegion = await _detectBestRegion();
    _currentRegion = bestRegion;

    debugPrint('ðŸ“ [GlobalNetwork] Selected region: ${bestRegion.name}');

    // Start periodic latency measurements
    _startLatencyMeasurements();

    // Start presence sync if user provided
    if (userId != null) {
      await globalPresenceSync(userId);
    }
  }

  /// Detect best region based on latency
  Future<Region> _detectBestRegion() async {
    final measurements = await Future.wait(
      Region.values.map((r) => _measureLatency(r)),
    );

    // Find region with lowest latency
    LatencyMeasurement? best;
    for (final m in measurements) {
      if (best == null || m.latencyMs < best.latencyMs) {
        best = m;
      }
    }

    return best?.region ?? Region.usEast;
  }

  /// Measure latency to a region
  Future<LatencyMeasurement> _measureLatency(Region region) async {
    final start = DateTime.now();

    // Simulate latency measurement (in production, ping actual edge nodes)
    await Future.delayed(Duration(milliseconds: _getSimulatedLatency(region)));

    final latency = DateTime.now().difference(start).inMilliseconds;

    final measurement = LatencyMeasurement(
      region: region,
      latencyMs: latency,
      measuredAt: DateTime.now(),
      packetLoss: math.Random().nextDouble() * 0.02, // 0-2% packet loss
      jitter: math.Random().nextDouble() * 10, // 0-10ms jitter
    );

    _latencyCache[region] = measurement;
    _latencyController.add(measurement);

    return measurement;
  }

  int _getSimulatedLatency(Region region) {
    // Simulated latencies (in production, measure actual RTT)
    const latencies = {
      Region.usEast: 20,
      Region.usWest: 40,
      Region.euWest: 80,
      Region.euCentral: 90,
      Region.asiaPacific: 150,
      Region.asiaSouth: 160,
      Region.southAmerica: 120,
      Region.australia: 180,
      Region.africa: 200,
    };
    return (latencies[region] ?? 100) + math.Random().nextInt(20);
  }

  void _startLatencyMeasurements() {
    _latencyMeasurementTimer?.cancel();
    _latencyMeasurementTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _measureAllRegions(),
    );
  }

  Future<void> _measureAllRegions() async {
    for (final region in Region.values) {
      await _measureLatency(region);
    }

    // Check if we should switch regions
    final best = await _detectBestRegion();
    if (best != _currentRegion) {
      final currentLatency = _latencyCache[_currentRegion]?.latencyMs ?? 999;
      final bestLatency = _latencyCache[best]?.latencyMs ?? 999;

      // Switch if significantly better (>20% improvement)
      if (bestLatency < currentLatency * 0.8) {
        debugPrint(
            'ðŸ”„ [GlobalNetwork] Switching region: ${_currentRegion?.name} -> ${best.name}');
        _currentRegion = best;
      }
    }
  }

  /// Get optimal route to a target region
  Future<List<Region>> getOptimalRoute(Region target) async {
    if (target == currentRegion) return [currentRegion];

    // Simple routing: direct or via intermediate
    final directLatency = _latencyCache[target]?.latencyMs ?? 999;

    // Check if going through another region is faster
    Region? bestIntermediate;
    var bestTotalLatency = directLatency;

    for (final intermediate in Region.values) {
      if (intermediate == currentRegion || intermediate == target) continue;

      final leg1 = _latencyCache[intermediate]?.latencyMs ?? 999;
      final leg2 = _getEstimatedLatency(intermediate, target);
      final totalLatency = leg1 + leg2;

      if (totalLatency < bestTotalLatency * 0.9) {
        bestIntermediate = intermediate;
        bestTotalLatency = totalLatency;
      }
    }

    if (bestIntermediate != null) {
      return [currentRegion, bestIntermediate, target];
    }

    return [currentRegion, target];
  }

  int _getEstimatedLatency(Region from, Region to) {
    // Simplified inter-region latency estimation
    final distance = _calculateRegionDistance(from, to);
    return (distance / 100 * 5).round(); // ~5ms per 100km
  }

  double _calculateRegionDistance(Region from, Region to) {
    // Simplified distance calculation based on region coordinates
    const coords = {
      Region.usEast: (40.7, -74.0),
      Region.usWest: (37.8, -122.4),
      Region.euWest: (51.5, -0.1),
      Region.euCentral: (52.5, 13.4),
      Region.asiaPacific: (35.7, 139.7),
      Region.asiaSouth: (19.1, 72.9),
      Region.southAmerica: (-23.5, -46.6),
      Region.australia: (-33.9, 151.2),
      Region.africa: (-26.2, 28.0),
    };

    final fromCoords = coords[from]!;
    final toCoords = coords[to]!;

    final lat1 = fromCoords.$1 * math.pi / 180;
    final lat2 = toCoords.$1 * math.pi / 180;
    final dLon = (toCoords.$2 - fromCoords.$2) * math.pi / 180;

    // Haversine formula (simplified)
    final a = math.sin((lat2 - lat1) / 2) * math.sin((lat2 - lat1) / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return 6371 * c; // Earth radius in km
  }

  // ============================================================
  // LATENCY ADAPTIVE VIDEO
  // ============================================================

  /// Get recommended video quality based on current latency
  VideoQuality latencyAdaptiveVideo() {
    final latency = _latencyCache[currentRegion]?.latencyMs ?? 100;
    final packetLoss = _latencyCache[currentRegion]?.packetLoss ?? 0;
    final jitter = _latencyCache[currentRegion]?.jitter ?? 0;

    // Calculate network score (0-100)
    var score = 100.0;
    score -= latency * 0.3; // -30 points for 100ms latency
    score -= packetLoss * 1000; // -10 points for 1% packet loss
    score -= jitter * 2; // -20 points for 10ms jitter

    debugPrint(
        'ðŸ“Š [GlobalNetwork] Network score: ${score.toStringAsFixed(1)}');

    if (score >= 90) return VideoQuality.uhd;
    if (score >= 75) return VideoQuality.hd;
    if (score >= 50) return VideoQuality.high;
    if (score >= 25) return VideoQuality.medium;
    return VideoQuality.low;
  }

  /// Get adaptive video settings
  Map<String, dynamic> getAdaptiveVideoSettings() {
    final quality = latencyAdaptiveVideo();
    final latency = _latencyCache[currentRegion]?.latencyMs ?? 100;

    // Adjust bitrate and FPS based on quality
    final settings = <String, dynamic>{
      'quality': quality.name,
      'resolution': _getResolution(quality),
      'fps': _getFPS(quality, latency),
      'bitrate': _getBitrate(quality),
      'keyframeInterval': _getKeyframeInterval(latency),
      'bufferSize': _getBufferSize(latency),
    };

    return settings;
  }

  String _getResolution(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.low:
        return '426x240';
      case VideoQuality.medium:
        return '854x480';
      case VideoQuality.high:
        return '1280x720';
      case VideoQuality.hd:
        return '1920x1080';
      case VideoQuality.uhd:
        return '3840x2160';
    }
  }

  int _getFPS(VideoQuality quality, int latency) {
    // Reduce FPS on high latency connections
    final baseFPS = switch (quality) {
      VideoQuality.low => 15,
      VideoQuality.medium => 24,
      VideoQuality.high => 30,
      VideoQuality.hd => 30,
      VideoQuality.uhd => 30,
    };

    if (latency > 200) return (baseFPS * 0.5).round();
    if (latency > 100) return (baseFPS * 0.8).round();
    return baseFPS;
  }

  int _getBitrate(VideoQuality quality) {
    return switch (quality) {
      VideoQuality.low => 400000, // 400 Kbps
      VideoQuality.medium => 1000000, // 1 Mbps
      VideoQuality.high => 2500000, // 2.5 Mbps
      VideoQuality.hd => 5000000, // 5 Mbps
      VideoQuality.uhd => 15000000, // 15 Mbps
    };
  }

  int _getKeyframeInterval(int latency) {
    // More frequent keyframes on lossy connections
    if (latency > 200) return 1;
    if (latency > 100) return 2;
    return 3;
  }

  int _getBufferSize(int latency) {
    // Larger buffer on high latency connections
    return latency * 3; // 3x latency in ms
  }

  // ============================================================
  // GLOBAL PRESENCE SYNC
  // ============================================================

  /// Sync user presence globally
  Future<void> globalPresenceSync(String userId) async {
    debugPrint('ðŸ‘¤ [GlobalNetwork] Starting presence sync for $userId');

    // Update presence immediately
    await _updatePresence(userId, isOnline: true);

    // Start periodic presence updates
    _presenceSyncTimer?.cancel();
    _presenceSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updatePresence(userId, isOnline: true),
    );
  }

  Future<void> _updatePresence(
    String userId, {
    bool isOnline = true,
    String? currentRoom,
  }) async {
    try {
      final presence = UserPresence(
        oderId: userId,
        region: currentRegion,
        currentRoom: currentRoom,
        lastSeen: DateTime.now(),
        isOnline: isOnline,
        edgeNode: await _getCurrentEdgeNode(),
      );

      await _presenceCollection.doc(userId).set(
            presence.toFirestore(),
            SetOptions(merge: true),
          );

      _presenceController.add(presence);
    } catch (e) {
      debugPrint('âŒ [GlobalNetwork] Failed to update presence: $e');
    }
  }

  Future<String?> _getCurrentEdgeNode() async {
    try {
      final regionDoc = await _regionsCollection.doc(currentRegion.name).get();
      if (!regionDoc.exists) return null;

      final data = regionDoc.data() as Map<String, dynamic>;
      final nodes = List<String>.from(data['edgeNodes'] ?? []);

      if (nodes.isEmpty) return null;
      return nodes[math.Random().nextInt(nodes.length)];
    } catch (_) {
      return null;
    }
  }

  /// Get user presence
  Future<UserPresence?> getUserPresence(String oderId) async {
    final doc = await _presenceCollection.doc(oderId).get();
    if (!doc.exists) return null;
    return UserPresence.fromFirestore(doc);
  }

  /// Get online users in region
  Future<List<UserPresence>> getOnlineUsersInRegion(Region region) async {
    final snapshot = await _presenceCollection
        .where('region', isEqualTo: region.name)
        .where('isOnline', isEqualTo: true)
        .limit(100)
        .get();

    return snapshot.docs.map((doc) => UserPresence.fromFirestore(doc)).toList();
  }

  /// Stop presence sync
  Future<void> stopPresenceSync(String userId) async {
    _presenceSyncTimer?.cancel();
    await _updatePresence(userId, isOnline: false);
    debugPrint('ðŸ‘¤ [GlobalNetwork] Presence sync stopped for $userId');
  }

  // ============================================================
  // CROSS-REGION ROOM MIRRORING
  // ============================================================

  /// Create room mirror to another region
  Future<RoomMirror> crossRegionRoomMirroring({
    required String roomId,
    required Region targetRegion,
  }) async {
    debugPrint(
        'ðŸªž [GlobalNetwork] Creating room mirror: $roomId -> ${targetRegion.name}');

    final mirrorRef = _mirrorsCollection.doc();
    final edgeNode = await _getEdgeNodeForRegion(targetRegion);

    final mirror = RoomMirror(
      mirrorId: mirrorRef.id,
      sourceRoom: roomId,
      sourceRegion: currentRegion,
      targetRegion: targetRegion,
      targetEdgeNode: edgeNode ?? 'default',
      createdAt: DateTime.now(),
      latencyMs: _latencyCache[targetRegion]?.latencyMs ?? 100,
      isActive: true,
    );

    await mirrorRef.set(mirror.toFirestore());

    debugPrint('âœ… [GlobalNetwork] Room mirror created: ${mirror.mirrorId}');
    return mirror;
  }

  Future<String?> _getEdgeNodeForRegion(Region region) async {
    try {
      final regionDoc = await _regionsCollection.doc(region.name).get();
      if (!regionDoc.exists) return null;

      final data = regionDoc.data() as Map<String, dynamic>;
      final nodes = List<String>.from(data['edgeNodes'] ?? []);

      if (nodes.isEmpty) return null;

      // Select node with lowest load (simplified)
      return nodes.first;
    } catch (_) {
      return null;
    }
  }

  /// Get mirrors for a room
  Future<List<RoomMirror>> getRoomMirrors(String roomId) async {
    final snapshot = await _mirrorsCollection
        .where('sourceRoom', isEqualTo: roomId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => RoomMirror.fromFirestore(doc)).toList();
  }

  /// Deactivate room mirror
  Future<void> deactivateRoomMirror(String mirrorId) async {
    await _mirrorsCollection.doc(mirrorId).update({
      'isActive': false,
    });
    debugPrint('ðŸªž [GlobalNetwork] Room mirror deactivated: $mirrorId');
  }

  // ============================================================
  // REGION MANAGEMENT
  // ============================================================

  /// Get all regions
  Future<List<RegionInfo>> getAllRegions() async {
    final snapshot = await _regionsCollection.get();
    return snapshot.docs.map((doc) => RegionInfo.fromFirestore(doc)).toList();
  }

  /// Get region info
  Future<RegionInfo?> getRegionInfo(Region region) async {
    final doc = await _regionsCollection.doc(region.name).get();
    if (!doc.exists) return null;
    return RegionInfo.fromFirestore(doc);
  }

  /// Get latency cache
  Map<Region, LatencyMeasurement> get latencyCache =>
      Map.unmodifiable(_latencyCache);

  void dispose() {
    _latencyMeasurementTimer?.cancel();
    _presenceSyncTimer?.cancel();
    _presenceController.close();
    _latencyController.close();
  }
}
