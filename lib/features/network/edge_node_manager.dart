/// Edge Node Manager
///
/// Manages edge nodes for low-latency content delivery and failover routing.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'global_network_service.dart';

/// Edge node status
enum EdgeNodeStatus {
  online,
  degraded,
  offline,
  maintenance,
  draining,
}

/// Edge node type
enum EdgeNodeType {
  primary,
  secondary,
  backup,
  cache,
}

/// Edge node information
class EdgeNode {
  final String id;
  final String name;
  final Region region;
  final EdgeNodeType type;
  final EdgeNodeStatus status;
  final String endpoint;
  final int port;
  final int currentConnections;
  final int maxConnections;
  final double cpuUsage;
  final double memoryUsage;
  final double bandwidthUsage;
  final DateTime lastHealthCheck;
  final Map<String, dynamic> metadata;

  const EdgeNode({
    required this.id,
    required this.name,
    required this.region,
    required this.type,
    required this.status,
    required this.endpoint,
    this.port = 443,
    this.currentConnections = 0,
    this.maxConnections = 10000,
    this.cpuUsage = 0,
    this.memoryUsage = 0,
    this.bandwidthUsage = 0,
    required this.lastHealthCheck,
    this.metadata = const {},
  });

  double get loadPercentage =>
      maxConnections > 0 ? currentConnections / maxConnections : 0;

  bool get isHealthy => status == EdgeNodeStatus.online && loadPercentage < 0.9;

  factory EdgeNode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EdgeNode(
      id: doc.id,
      name: data['name'] ?? '',
      region: Region.values.firstWhere(
        (r) => r.name == data['region'],
        orElse: () => Region.usEast,
      ),
      type: EdgeNodeType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => EdgeNodeType.primary,
      ),
      status: EdgeNodeStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => EdgeNodeStatus.online,
      ),
      endpoint: data['endpoint'] ?? '',
      port: data['port'] ?? 443,
      currentConnections: data['currentConnections'] ?? 0,
      maxConnections: data['maxConnections'] ?? 10000,
      cpuUsage: (data['cpuUsage'] ?? 0).toDouble(),
      memoryUsage: (data['memoryUsage'] ?? 0).toDouble(),
      bandwidthUsage: (data['bandwidthUsage'] ?? 0).toDouble(),
      lastHealthCheck:
          (data['lastHealthCheck'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'region': region.name,
        'type': type.name,
        'status': status.name,
        'endpoint': endpoint,
        'port': port,
        'currentConnections': currentConnections,
        'maxConnections': maxConnections,
        'cpuUsage': cpuUsage,
        'memoryUsage': memoryUsage,
        'bandwidthUsage': bandwidthUsage,
        'lastHealthCheck': Timestamp.fromDate(lastHealthCheck),
        'metadata': metadata,
      };
}

/// User-to-edge assignment
class EdgeAssignment {
  final String oderId;
  final String edgeNodeId;
  final Region region;
  final DateTime assignedAt;
  final int latencyMs;
  final bool isPrimary;

  const EdgeAssignment({
    required this.oderId,
    required this.edgeNodeId,
    required this.region,
    required this.assignedAt,
    this.latencyMs = 0,
    this.isPrimary = true,
  });

  factory EdgeAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EdgeAssignment(
      oderId: doc.id,
      edgeNodeId: data['edgeNodeId'] ?? '',
      region: Region.values.firstWhere(
        (r) => r.name == data['region'],
        orElse: () => Region.usEast,
      ),
      assignedAt:
          (data['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latencyMs: data['latencyMs'] ?? 0,
      isPrimary: data['isPrimary'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'edgeNodeId': edgeNodeId,
        'region': region.name,
        'assignedAt': Timestamp.fromDate(assignedAt),
        'latencyMs': latencyMs,
        'isPrimary': isPrimary,
      };
}

/// Failover event
class FailoverEvent {
  final String id;
  final String oderId;
  final String fromNode;
  final String toNode;
  final String reason;
  final DateTime timestamp;
  final int downtimeMs;
  final bool successful;

  const FailoverEvent({
    required this.id,
    required this.oderId,
    required this.fromNode,
    required this.toNode,
    required this.reason,
    required this.timestamp,
    this.downtimeMs = 0,
    this.successful = true,
  });

  factory FailoverEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FailoverEvent(
      id: doc.id,
      oderId: data['userId'] ?? '',
      fromNode: data['fromNode'] ?? '',
      toNode: data['toNode'] ?? '',
      reason: data['reason'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      downtimeMs: data['downtimeMs'] ?? 0,
      successful: data['successful'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': oderId,
        'fromNode': fromNode,
        'toNode': toNode,
        'reason': reason,
        'timestamp': Timestamp.fromDate(timestamp),
        'downtimeMs': downtimeMs,
        'successful': successful,
      };
}

/// Edge node manager singleton
class EdgeNodeManager {
  static EdgeNodeManager? _instance;
  static EdgeNodeManager get instance => _instance ??= EdgeNodeManager._();

  EdgeNodeManager._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _nodesCollection =>
      _firestore.collection('edge_nodes');
  CollectionReference get _assignmentsCollection =>
      _firestore.collection('edge_assignments');
  CollectionReference get _failoversCollection =>
      _firestore.collection('failover_events');

  final StreamController<EdgeNode> _nodeStatusController =
      StreamController<EdgeNode>.broadcast();
  final StreamController<FailoverEvent> _failoverController =
      StreamController<FailoverEvent>.broadcast();

  Stream<EdgeNode> get nodeStatusStream => _nodeStatusController.stream;
  Stream<FailoverEvent> get failoverStream => _failoverController.stream;

  Timer? _healthCheckTimer;
  final Map<String, EdgeNode> _nodeCache = {};

  // ============================================================
  // EDGE NODE REGISTRATION
  // ============================================================

  /// Register a new edge node
  Future<EdgeNode> registerEdgeNode({
    required String name,
    required Region region,
    required String endpoint,
    EdgeNodeType type = EdgeNodeType.primary,
    int port = 443,
    int maxConnections = 10000,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint(
        'ðŸ–¥ï¸ [EdgeManager] Registering edge node: $name in ${region.name}');

    final nodeRef = _nodesCollection.doc();
    final node = EdgeNode(
      id: nodeRef.id,
      name: name,
      region: region,
      type: type,
      status: EdgeNodeStatus.online,
      endpoint: endpoint,
      port: port,
      maxConnections: maxConnections,
      lastHealthCheck: DateTime.now(),
      metadata: metadata ?? {},
    );

    await nodeRef.set(node.toFirestore());
    _nodeCache[node.id] = node;

    debugPrint('âœ… [EdgeManager] Edge node registered: ${node.id}');
    return node;
  }

  /// Update edge node status
  Future<void> updateNodeStatus(String nodeId, EdgeNodeStatus status) async {
    await _nodesCollection.doc(nodeId).update({
      'status': status.name,
      'lastHealthCheck': Timestamp.now(),
    });

    debugPrint('ðŸ“Š [EdgeManager] Node $nodeId status: ${status.name}');

    // Trigger failover if node went offline
    if (status == EdgeNodeStatus.offline ||
        status == EdgeNodeStatus.maintenance) {
      await _triggerFailoverForNode(nodeId);
    }
  }

  /// Update node metrics
  Future<void> updateNodeMetrics(
    String nodeId, {
    int? currentConnections,
    double? cpuUsage,
    double? memoryUsage,
    double? bandwidthUsage,
  }) async {
    final updates = <String, dynamic>{
      'lastHealthCheck': Timestamp.now(),
    };

    if (currentConnections != null) {
      updates['currentConnections'] = currentConnections;
    }
    if (cpuUsage != null) updates['cpuUsage'] = cpuUsage;
    if (memoryUsage != null) updates['memoryUsage'] = memoryUsage;
    if (bandwidthUsage != null) updates['bandwidthUsage'] = bandwidthUsage;

    await _nodesCollection.doc(nodeId).update(updates);
  }

  /// Deregister edge node
  Future<void> deregisterEdgeNode(String nodeId) async {
    // Drain connections first
    await updateNodeStatus(nodeId, EdgeNodeStatus.draining);

    // Wait for connections to drain (in production, wait longer)
    await Future.delayed(const Duration(seconds: 2));

    // Trigger failover for remaining users
    await _triggerFailoverForNode(nodeId);

    // Delete node
    await _nodesCollection.doc(nodeId).delete();
    _nodeCache.remove(nodeId);

    debugPrint('ðŸ—‘ï¸ [EdgeManager] Edge node deregistered: $nodeId');
  }

  // ============================================================
  // USER ASSIGNMENT
  // ============================================================

  /// Assign user to optimal edge node
  Future<EdgeAssignment> assignUsersToEdge({
    required String oderId,
    Region? preferredRegion,
  }) async {
    debugPrint('ðŸ‘¤ [EdgeManager] Assigning user $oderId to edge');

    final region =
        preferredRegion ?? GlobalNetworkService.instance.currentRegion;
    final node = await _selectBestNode(region);

    if (node == null) {
      throw Exception('No available edge nodes in region ${region.name}');
    }

    final assignment = EdgeAssignment(
      oderId: oderId,
      edgeNodeId: node.id,
      region: region,
      assignedAt: DateTime.now(),
      latencyMs: await _measureNodeLatency(node),
      isPrimary: true,
    );

    await _assignmentsCollection.doc(oderId).set(assignment.toFirestore());

    // Increment connection count
    await _nodesCollection.doc(node.id).update({
      'currentConnections': FieldValue.increment(1),
    });

    debugPrint('âœ… [EdgeManager] User $oderId assigned to ${node.name}');
    return assignment;
  }

  /// Select best node for region
  Future<EdgeNode?> _selectBestNode(Region region) async {
    final snapshot = await _nodesCollection
        .where('region', isEqualTo: region.name)
        .where('status', isEqualTo: EdgeNodeStatus.online.name)
        .get();

    if (snapshot.docs.isEmpty) {
      // Fallback to any online node
      final fallbackSnapshot = await _nodesCollection
          .where('status', isEqualTo: EdgeNodeStatus.online.name)
          .limit(10)
          .get();

      if (fallbackSnapshot.docs.isEmpty) return null;

      final nodes = fallbackSnapshot.docs
          .map((doc) => EdgeNode.fromFirestore(doc))
          .toList();

      return _selectLeastLoadedNode(nodes);
    }

    final nodes =
        snapshot.docs.map((doc) => EdgeNode.fromFirestore(doc)).toList();
    return _selectLeastLoadedNode(nodes);
  }

  EdgeNode? _selectLeastLoadedNode(List<EdgeNode> nodes) {
    if (nodes.isEmpty) return null;

    final healthyNodes = nodes.where((n) => n.isHealthy).toList();
    if (healthyNodes.isEmpty) {
      return nodes.first; // Return any node if none are healthy
    }

    // Sort by load percentage
    healthyNodes.sort((a, b) => a.loadPercentage.compareTo(b.loadPercentage));
    return healthyNodes.first;
  }

  Future<int> _measureNodeLatency(EdgeNode node) async {
    // Simulate latency measurement
    return 20 + math.Random().nextInt(30);
  }

  /// Release user from edge node
  Future<void> releaseUserFromEdge(String oderId) async {
    final assignmentDoc = await _assignmentsCollection.doc(oderId).get();
    if (!assignmentDoc.exists) return;

    final assignment = EdgeAssignment.fromFirestore(assignmentDoc);

    // Decrement connection count
    await _nodesCollection.doc(assignment.edgeNodeId).update({
      'currentConnections': FieldValue.increment(-1),
    });

    await _assignmentsCollection.doc(oderId).delete();

    debugPrint('ðŸ‘¤ [EdgeManager] User $oderId released from edge');
  }

  /// Get user's current assignment
  Future<EdgeAssignment?> getUserAssignment(String oderId) async {
    final doc = await _assignmentsCollection.doc(oderId).get();
    if (!doc.exists) return null;
    return EdgeAssignment.fromFirestore(doc);
  }

  // ============================================================
  // FAILOVER ROUTING
  // ============================================================

  /// Perform failover for user
  Future<FailoverEvent> failoverRouting({
    required String oderId,
    required String reason,
  }) async {
    debugPrint('ðŸ”„ [EdgeManager] Initiating failover for $oderId: $reason');

    final start = DateTime.now();
    final currentAssignment = await getUserAssignment(oderId);

    if (currentAssignment == null) {
      throw Exception('User $oderId has no edge assignment');
    }

    // Find alternative node
    final region = currentAssignment.region;
    final excludeNode = currentAssignment.edgeNodeId;

    final newNode = await _selectAlternativeNode(region, excludeNode);

    if (newNode == null) {
      throw Exception('No alternative edge nodes available');
    }

    // Perform failover
    final failoverRef = _failoversCollection.doc();
    final failover = FailoverEvent(
      id: failoverRef.id,
      oderId: oderId,
      fromNode: currentAssignment.edgeNodeId,
      toNode: newNode.id,
      reason: reason,
      timestamp: DateTime.now(),
      downtimeMs: DateTime.now().difference(start).inMilliseconds,
      successful: true,
    );

    // Update assignment
    await _assignmentsCollection.doc(oderId).update({
      'edgeNodeId': newNode.id,
      'assignedAt': Timestamp.now(),
      'latencyMs': await _measureNodeLatency(newNode),
    });

    // Update connection counts
    await _nodesCollection.doc(currentAssignment.edgeNodeId).update({
      'currentConnections': FieldValue.increment(-1),
    });
    await _nodesCollection.doc(newNode.id).update({
      'currentConnections': FieldValue.increment(1),
    });

    // Record failover event
    await failoverRef.set(failover.toFirestore());
    _failoverController.add(failover);

    debugPrint('âœ… [EdgeManager] Failover complete: ${newNode.name}');
    return failover;
  }

  Future<EdgeNode?> _selectAlternativeNode(
      Region region, String excludeNode) async {
    // First try same region
    var snapshot = await _nodesCollection
        .where('region', isEqualTo: region.name)
        .where('status', isEqualTo: EdgeNodeStatus.online.name)
        .get();

    var nodes = snapshot.docs
        .map((doc) => EdgeNode.fromFirestore(doc))
        .where((n) => n.id != excludeNode)
        .toList();

    if (nodes.isNotEmpty) {
      return _selectLeastLoadedNode(nodes);
    }

    // Try nearby regions
    for (final nearbyRegion in _getNearbyRegions(region)) {
      snapshot = await _nodesCollection
          .where('region', isEqualTo: nearbyRegion.name)
          .where('status', isEqualTo: EdgeNodeStatus.online.name)
          .limit(5)
          .get();

      nodes = snapshot.docs.map((doc) => EdgeNode.fromFirestore(doc)).toList();

      if (nodes.isNotEmpty) {
        return _selectLeastLoadedNode(nodes);
      }
    }

    return null;
  }

  List<Region> _getNearbyRegions(Region region) {
    const nearbyMap = {
      Region.usEast: [Region.usWest, Region.euWest],
      Region.usWest: [Region.usEast, Region.asiaPacific],
      Region.euWest: [Region.euCentral, Region.usEast],
      Region.euCentral: [Region.euWest, Region.asiaSouth],
      Region.asiaPacific: [Region.asiaSouth, Region.australia],
      Region.asiaSouth: [Region.asiaPacific, Region.euCentral],
      Region.southAmerica: [Region.usEast, Region.africa],
      Region.australia: [Region.asiaPacific, Region.asiaSouth],
      Region.africa: [Region.euWest, Region.southAmerica],
    };

    return nearbyMap[region] ?? [Region.usEast];
  }

  /// Trigger failover for all users on a node
  Future<void> _triggerFailoverForNode(String nodeId) async {
    debugPrint(
        'ðŸ”„ [EdgeManager] Triggering failover for all users on node $nodeId');

    final snapshot = await _assignmentsCollection
        .where('edgeNodeId', isEqualTo: nodeId)
        .get();

    for (final doc in snapshot.docs) {
      try {
        await failoverRouting(
          oderId: doc.id,
          reason: 'Node $nodeId unavailable',
        );
      } catch (e) {
        debugPrint('âŒ [EdgeManager] Failover failed for ${doc.id}: $e');
      }
    }
  }

  // ============================================================
  // HEALTH MONITORING
  // ============================================================

  /// Start health check monitoring
  void startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHealthChecks(),
    );
    debugPrint('ðŸ’“ [EdgeManager] Health monitoring started');
  }

  Future<void> _performHealthChecks() async {
    final snapshot = await _nodesCollection.get();

    for (final doc in snapshot.docs) {
      final node = EdgeNode.fromFirestore(doc);

      // Check if node is healthy
      if (node.lastHealthCheck.difference(DateTime.now()).abs() >
          const Duration(minutes: 2)) {
        // Node hasn't reported recently
        await updateNodeStatus(node.id, EdgeNodeStatus.degraded);
      }

      // Update cache
      _nodeCache[node.id] = node;
      _nodeStatusController.add(node);
    }
  }

  /// Stop health monitoring
  void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    debugPrint('ðŸ’“ [EdgeManager] Health monitoring stopped');
  }

  // ============================================================
  // QUERIES
  // ============================================================

  /// Get all edge nodes
  Future<List<EdgeNode>> getAllEdgeNodes() async {
    final snapshot = await _nodesCollection.get();
    return snapshot.docs.map((doc) => EdgeNode.fromFirestore(doc)).toList();
  }

  /// Get nodes by region
  Future<List<EdgeNode>> getNodesByRegion(Region region) async {
    final snapshot =
        await _nodesCollection.where('region', isEqualTo: region.name).get();
    return snapshot.docs.map((doc) => EdgeNode.fromFirestore(doc)).toList();
  }

  /// Get node by ID
  Future<EdgeNode?> getNode(String nodeId) async {
    if (_nodeCache.containsKey(nodeId)) {
      return _nodeCache[nodeId];
    }

    final doc = await _nodesCollection.doc(nodeId).get();
    if (!doc.exists) return null;

    final node = EdgeNode.fromFirestore(doc);
    _nodeCache[nodeId] = node;
    return node;
  }

  /// Get failover history
  Future<List<FailoverEvent>> getFailoverHistory({
    String? oderId,
    int limit = 50,
  }) async {
    var query = _failoversCollection.orderBy('timestamp', descending: true);

    if (oderId != null) {
      query = query.where('userId', isEqualTo: oderId);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => FailoverEvent.fromFirestore(doc))
        .toList();
  }

  /// Get edge statistics
  Future<Map<String, dynamic>> getEdgeStatistics() async {
    final nodes = await getAllEdgeNodes();

    var totalConnections = 0;
    var totalCapacity = 0;
    final byRegion = <String, int>{};
    final byStatus = <String, int>{};

    for (final node in nodes) {
      totalConnections += node.currentConnections;
      totalCapacity += node.maxConnections;
      byRegion[node.region.name] = (byRegion[node.region.name] ?? 0) + 1;
      byStatus[node.status.name] = (byStatus[node.status.name] ?? 0) + 1;
    }

    return {
      'totalNodes': nodes.length,
      'totalConnections': totalConnections,
      'totalCapacity': totalCapacity,
      'utilizationPercent':
          totalCapacity > 0 ? totalConnections / totalCapacity * 100 : 0,
      'byRegion': byRegion,
      'byStatus': byStatus,
      'healthyNodes': nodes.where((n) => n.isHealthy).length,
    };
  }

  void dispose() {
    _healthCheckTimer?.cancel();
    _nodeStatusController.close();
    _failoverController.close();
  }
}
