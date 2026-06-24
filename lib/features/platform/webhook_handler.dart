/// Webhook Handler
///
/// Manages webhook registrations, deliveries, and event
/// handling for the Mix & Mingle platform.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';

/// Webhook event types
enum WebhookEventType {
  // Room events
  roomCreated,
  roomStarted,
  roomEnded,
  roomParticipantJoined,
  roomParticipantLeft,

  // User events
  userRegistered,
  userVerified,
  userSubscribed,
  userUnsubscribed,

  // Creator events
  creatorApproved,
  creatorLevelUp,
  creatorPayout,

  // Payment events
  paymentSucceeded,
  paymentFailed,
  subscriptionCreated,
  subscriptionCanceled,
  refundProcessed,

  // Content events
  messageReported,
  contentFlagged,
  contentRemoved,

  // Platform events
  integrationConnected,
  integrationDisconnected,
}

/// Webhook registration
class WebhookRegistration {
  final String id;
  final String appId;
  final String url;
  final String secret;
  final List<WebhookEventType> events;
  final bool enabled;
  final WebhookFormat format;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime? lastTriggeredAt;

  const WebhookRegistration({
    required this.id,
    required this.appId,
    required this.url,
    required this.secret,
    required this.events,
    this.enabled = true,
    this.format = WebhookFormat.json,
    this.maxRetries = 3,
    required this.createdAt,
    this.lastTriggeredAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'appId': appId,
        'url': url,
        'secretHash': _hashSecret(secret),
        'events': events.map((e) => e.name).toList(),
        'enabled': enabled,
        'format': format.name,
        'maxRetries': maxRetries,
        'createdAt': createdAt.toIso8601String(),
        'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
      };

  static String _hashSecret(String secret) {
    return sha256.convert(utf8.encode(secret)).toString();
  }

  factory WebhookRegistration.fromMap(Map<String, dynamic> map) =>
      WebhookRegistration(
        id: map['id'] as String,
        appId: map['appId'] as String,
        url: map['url'] as String,
        secret: '', // Secret is not stored directly
        events: (map['events'] as List)
            .map((e) => WebhookEventType.values.firstWhere(
                  (t) => t.name == e,
                  orElse: () => WebhookEventType.roomCreated,
                ))
            .toList(),
        enabled: map['enabled'] as bool? ?? true,
        format: WebhookFormat.values.firstWhere(
          (f) => f.name == map['format'],
          orElse: () => WebhookFormat.json,
        ),
        maxRetries: map['maxRetries'] as int? ?? 3,
        createdAt: DateTime.parse(map['createdAt'] as String),
        lastTriggeredAt: map['lastTriggeredAt'] != null
            ? DateTime.parse(map['lastTriggeredAt'] as String)
            : null,
      );
}

enum WebhookFormat {
  json,
  formData,
}

/// Webhook payload
class WebhookPayload {
  final String id;
  final WebhookEventType event;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String signature;

  const WebhookPayload({
    required this.id,
    required this.event,
    required this.data,
    required this.timestamp,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'event': event.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'signature': signature,
      };

  String toJsonString() => jsonEncode(toJson());
}

/// Webhook delivery result
class WebhookDeliveryResult {
  final String webhookId;
  final String deliveryId;
  final bool success;
  final int statusCode;
  final String? error;
  final int attemptNumber;
  final Duration responseTime;
  final DateTime deliveredAt;

  const WebhookDeliveryResult({
    required this.webhookId,
    required this.deliveryId,
    required this.success,
    required this.statusCode,
    this.error,
    required this.attemptNumber,
    required this.responseTime,
    required this.deliveredAt,
  });

  Map<String, dynamic> toMap() => {
        'webhookId': webhookId,
        'deliveryId': deliveryId,
        'success': success,
        'statusCode': statusCode,
        'error': error,
        'attemptNumber': attemptNumber,
        'responseTimeMs': responseTime.inMilliseconds,
        'deliveredAt': deliveredAt.toIso8601String(),
      };
}

/// Webhook statistics
class WebhookStats {
  final String webhookId;
  final int totalDeliveries;
  final int successfulDeliveries;
  final int failedDeliveries;
  final double successRate;
  final Duration averageResponseTime;
  final Map<String, int> deliveriesByEvent;

  const WebhookStats({
    required this.webhookId,
    required this.totalDeliveries,
    required this.successfulDeliveries,
    required this.failedDeliveries,
    required this.successRate,
    required this.averageResponseTime,
    this.deliveriesByEvent = const {},
  });
}

/// Webhook Handler Service
class WebhookHandler {
  static WebhookHandler? _instance;
  static WebhookHandler get instance => _instance ??= WebhookHandler._();

  WebhookHandler._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _random = Random.secure();

  // Stream controllers
  final _deliveryController =
      StreamController<WebhookDeliveryResult>.broadcast();

  Stream<WebhookDeliveryResult> get deliveryStream =>
      _deliveryController.stream;

  // Collections
  CollectionReference<Map<String, dynamic>> get _webhooksCollection =>
      _firestore.collection('webhooks');

  CollectionReference<Map<String, dynamic>> get _deliveriesCollection =>
      _firestore.collection('webhook_deliveries');

  // ============================================================
  // WEBHOOK REGISTRATION
  // ============================================================

  /// Register a new webhook
  Future<WebhookRegistration> registerWebhook({
    required String appId,
    required String url,
    required List<WebhookEventType> events,
    WebhookFormat format = WebhookFormat.json,
    int maxRetries = 3,
  }) async {
    debugPrint('ðŸ”— [WebhookHandler] Registering webhook for app: $appId');

    try {
      final id = _generateWebhookId();
      final secret = _generateWebhookSecret();

      final webhook = WebhookRegistration(
        id: id,
        appId: appId,
        url: url,
        secret: secret,
        events: events,
        format: format,
        maxRetries: maxRetries,
        createdAt: DateTime.now(),
      );

      // Store webhook
      await _webhooksCollection.doc(id).set(webhook.toMap());

      // Store secret separately (encrypted in production)
      await _firestore.collection('webhook_secrets').doc(id).set({
        'secret': secret,
        'createdAt': DateTime.now().toIso8601String(),
      });

      AnalyticsService.instance.logEvent(
        name: 'webhook_registered',
        parameters: {
          'app_id': appId,
          'events_count': events.length,
        },
      );

      debugPrint('âœ… [WebhookHandler] Webhook registered: $id');
      return webhook;
    } catch (e) {
      debugPrint('âŒ [WebhookHandler] Failed to register webhook: $e');
      rethrow;
    }
  }

  String _generateWebhookId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(999999).toString().padLeft(6, '0');
    return 'whk_${timestamp}_$random';
  }

  String _generateWebhookSecret() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return 'whsec_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  /// Update webhook events
  Future<bool> updateWebhookEvents(
    String webhookId,
    List<WebhookEventType> events,
  ) async {
    try {
      await _webhooksCollection.doc(webhookId).update({
        'events': events.map((e) => e.name).toList(),
      });
      return true;
    } catch (e) {
      debugPrint('âŒ [WebhookHandler] Failed to update webhook: $e');
      return false;
    }
  }

  /// Enable/disable webhook
  Future<bool> setWebhookEnabled(String webhookId, bool enabled) async {
    try {
      await _webhooksCollection.doc(webhookId).update({
        'enabled': enabled,
      });
      return true;
    } catch (e) {
      debugPrint('âŒ [WebhookHandler] Failed to toggle webhook: $e');
      return false;
    }
  }

  /// Delete a webhook
  Future<bool> deleteWebhook(String webhookId) async {
    try {
      await _webhooksCollection.doc(webhookId).delete();
      await _firestore.collection('webhook_secrets').doc(webhookId).delete();
      return true;
    } catch (e) {
      debugPrint('âŒ [WebhookHandler] Failed to delete webhook: $e');
      return false;
    }
  }

  // ============================================================
  // EVENT DISPATCHING
  // ============================================================

  /// Dispatch an event to all registered webhooks
  Future<List<WebhookDeliveryResult>> dispatchEvent({
    required WebhookEventType event,
    required Map<String, dynamic> data,
    String? targetAppId,
  }) async {
    debugPrint('ðŸ“¤ [WebhookHandler] Dispatching event: ${event.name}');

    try {
      // Find matching webhooks
      Query<Map<String, dynamic>> query = _webhooksCollection
          .where('enabled', isEqualTo: true)
          .where('events', arrayContains: event.name);

      if (targetAppId != null) {
        query = query.where('appId', isEqualTo: targetAppId);
      }

      final snapshot = await query.get();
      final results = <WebhookDeliveryResult>[];

      for (final doc in snapshot.docs) {
        final webhook = WebhookRegistration.fromMap(doc.data());
        final result = await _deliverWebhook(webhook, event, data);
        results.add(result);
        _deliveryController.add(result);
      }

      debugPrint(
          'âœ… [WebhookHandler] Dispatched to ${results.length} webhooks');
      return results;
    } catch (e) {
      debugPrint('âŒ [WebhookHandler] Event dispatch failed: $e');
      return [];
    }
  }

  Future<WebhookDeliveryResult> _deliverWebhook(
    WebhookRegistration webhook,
    WebhookEventType event,
    Map<String, dynamic> data,
  ) async {
    final deliveryId = _generateDeliveryId();
    final startTime = DateTime.now();

    try {
      // Get webhook secret
      final secretDoc =
          await _firestore.collection('webhook_secrets').doc(webhook.id).get();
      final secret = secretDoc.data()?['secret'] as String? ?? '';

      // Create payload
      final payload = WebhookPayload(
        id: deliveryId,
        event: event,
        data: data,
        timestamp: startTime,
        signature: _signPayload(data, secret),
      );

      // Simulate HTTP request (in production, use http package)
      await Future.delayed(const Duration(milliseconds: 100));

      final responseTime = DateTime.now().difference(startTime);
      final success =
          _random.nextDouble() > 0.05; // 95% success rate simulation

      final result = WebhookDeliveryResult(
        webhookId: webhook.id,
        deliveryId: deliveryId,
        success: success,
        statusCode: success ? 200 : 500,
        attemptNumber: 1,
        responseTime: responseTime,
        deliveredAt: DateTime.now(),
      );

      // Store delivery record
      await _deliveriesCollection.doc(deliveryId).set({
        ...result.toMap(),
        'payload': payload.toJson(),
      });

      // Update webhook last triggered
      await _webhooksCollection.doc(webhook.id).update({
        'lastTriggeredAt': DateTime.now().toIso8601String(),
      });

      return result;
    } catch (e) {
      final result = WebhookDeliveryResult(
        webhookId: webhook.id,
        deliveryId: deliveryId,
        success: false,
        statusCode: 0,
        error: e.toString(),
        attemptNumber: 1,
        responseTime: DateTime.now().difference(startTime),
        deliveredAt: DateTime.now(),
      );

      await _deliveriesCollection.doc(deliveryId).set(result.toMap());
      return result;
    }
  }

  String _generateDeliveryId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(999999).toString().padLeft(6, '0');
    return 'del_${timestamp}_$random';
  }

  String _signPayload(Map<String, dynamic> data, String secret) {
    final payload = jsonEncode(data);
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  // ============================================================
  // RETRIEVAL & STATISTICS
  // ============================================================

  /// Get webhooks for an app
  Future<List<WebhookRegistration>> getWebhooksForApp(String appId) async {
    final snapshot =
        await _webhooksCollection.where('appId', isEqualTo: appId).get();

    return snapshot.docs
        .map((doc) => WebhookRegistration.fromMap(doc.data()))
        .toList();
  }

  /// Get webhook delivery history
  Future<List<WebhookDeliveryResult>> getDeliveryHistory(
    String webhookId, {
    int limit = 50,
  }) async {
    final snapshot = await _deliveriesCollection
        .where('webhookId', isEqualTo: webhookId)
        .orderBy('deliveredAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return WebhookDeliveryResult(
        webhookId: data['webhookId'] as String,
        deliveryId: data['deliveryId'] as String,
        success: data['success'] as bool,
        statusCode: data['statusCode'] as int,
        error: data['error'] as String?,
        attemptNumber: data['attemptNumber'] as int,
        responseTime: Duration(milliseconds: data['responseTimeMs'] as int),
        deliveredAt: DateTime.parse(data['deliveredAt'] as String),
      );
    }).toList();
  }

  /// Get webhook statistics
  Future<WebhookStats> getWebhookStats(String webhookId) async {
    final deliveries = await getDeliveryHistory(webhookId, limit: 1000);

    final successful = deliveries.where((d) => d.success).length;
    final failed = deliveries.length - successful;
    final totalResponseTime = deliveries.fold<int>(
      0,
      (total, d) => total + d.responseTime.inMilliseconds,
    );

    final deliveriesByEvent = <String, int>{};
    // Count would require storing event type in delivery record

    return WebhookStats(
      webhookId: webhookId,
      totalDeliveries: deliveries.length,
      successfulDeliveries: successful,
      failedDeliveries: failed,
      successRate:
          deliveries.isEmpty ? 0 : successful / deliveries.length * 100,
      averageResponseTime: Duration(
        milliseconds:
            deliveries.isEmpty ? 0 : totalResponseTime ~/ deliveries.length,
      ),
      deliveriesByEvent: deliveriesByEvent,
    );
  }

  /// Verify webhook signature
  bool verifySignature(
    String payload,
    String signature,
    String secret,
  ) {
    final expectedSignature =
        _signPayload(jsonDecode(payload) as Map<String, dynamic>, secret);
    return signature == expectedSignature;
  }

  /// Dispose resources
  void dispose() {
    _deliveryController.close();
  }
}
