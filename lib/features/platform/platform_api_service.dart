/// Platform API Service
///
/// Manages external app registration, authentication, and API exposure
/// for the Mix & Mingle platform ecosystem.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';

/// External app registration
class ExternalApp {
  final String appId;
  final String name;
  final String description;
  final String developerEmail;
  final AppType type;
  final AppStatus status;
  final List<String> scopes;
  final String? clientId;
  final String? clientSecretHash;
  final String? webhookUrl;
  final String? redirectUri;
  final DateTime registeredAt;
  final DateTime? approvedAt;
  final Map<String, dynamic> metadata;

  const ExternalApp({
    required this.appId,
    required this.name,
    required this.description,
    required this.developerEmail,
    required this.type,
    required this.status,
    required this.scopes,
    this.clientId,
    this.clientSecretHash,
    this.webhookUrl,
    this.redirectUri,
    required this.registeredAt,
    this.approvedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'appId': appId,
        'name': name,
        'description': description,
        'developerEmail': developerEmail,
        'type': type.name,
        'status': status.name,
        'scopes': scopes,
        'clientId': clientId,
        'clientSecretHash': clientSecretHash,
        'webhookUrl': webhookUrl,
        'redirectUri': redirectUri,
        'registeredAt': registeredAt.toIso8601String(),
        'approvedAt': approvedAt?.toIso8601String(),
        'metadata': metadata,
      };

  factory ExternalApp.fromMap(Map<String, dynamic> map) => ExternalApp(
        appId: map['appId'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        developerEmail: map['developerEmail'] as String,
        type: AppType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => AppType.thirdParty,
        ),
        status: AppStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => AppStatus.pending,
        ),
        scopes: List<String>.from(map['scopes'] ?? []),
        clientId: map['clientId'] as String?,
        clientSecretHash: map['clientSecretHash'] as String?,
        webhookUrl: map['webhookUrl'] as String?,
        redirectUri: map['redirectUri'] as String?,
        registeredAt: DateTime.parse(map['registeredAt'] as String),
        approvedAt: map['approvedAt'] != null
            ? DateTime.parse(map['approvedAt'] as String)
            : null,
        metadata: (map['metadata'] as Map<String, dynamic>?) ?? {},
      );
}

/// App types
enum AppType {
  thirdParty,
  partner,
  enterprise,
  internal,
}

/// App status
enum AppStatus {
  pending,
  approved,
  suspended,
  rejected,
  revoked,
}

/// API scopes
class APIScopes {
  static const String roomsRead = 'rooms:read';
  static const String roomsWrite = 'rooms:write';
  static const String usersRead = 'users:read';
  static const String usersWrite = 'users:write';
  static const String analyticsRead = 'analytics:read';
  static const String messagesRead = 'messages:read';
  static const String messagesWrite = 'messages:write';
  static const String creatorsRead = 'creators:read';
  static const String creatorsWrite = 'creators:write';
  static const String paymentsRead = 'payments:read';
  static const String paymentsWrite = 'payments:write';
  static const String webhooksManage = 'webhooks:manage';

  static const List<String> all = [
    roomsRead,
    roomsWrite,
    usersRead,
    usersWrite,
    analyticsRead,
    messagesRead,
    messagesWrite,
    creatorsRead,
    creatorsWrite,
    paymentsRead,
    paymentsWrite,
    webhooksManage,
  ];
}

/// External client credentials
class ClientCredentials {
  final String clientId;
  final String clientSecret;
  final List<String> scopes;
  final DateTime expiresAt;

  const ClientCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.scopes,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Access token
class AccessToken {
  final String token;
  final String appId;
  final List<String> scopes;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const AccessToken({
    required this.token,
    required this.appId,
    required this.scopes,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'token': token,
        'appId': appId,
        'scopes': scopes,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// API endpoint definition
class APIEndpoint {
  final String path;
  final String method;
  final List<String> requiredScopes;
  final String description;
  final bool rateLimit;
  final int? maxRequestsPerMinute;

  const APIEndpoint({
    required this.path,
    required this.method,
    required this.requiredScopes,
    required this.description,
    this.rateLimit = true,
    this.maxRequestsPerMinute = 60,
  });

  Map<String, dynamic> toMap() => {
        'path': path,
        'method': method,
        'requiredScopes': requiredScopes,
        'description': description,
        'rateLimit': rateLimit,
        'maxRequestsPerMinute': maxRequestsPerMinute,
      };
}

/// Platform API Service for managing external integrations
class PlatformAPIService {
  static PlatformAPIService? _instance;
  static PlatformAPIService get instance =>
      _instance ??= PlatformAPIService._();

  PlatformAPIService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _random = Random.secure();

  // Stream controllers
  final _appController = StreamController<ExternalApp>.broadcast();
  final _tokenController = StreamController<AccessToken>.broadcast();

  Stream<ExternalApp> get appStream => _appController.stream;
  Stream<AccessToken> get tokenStream => _tokenController.stream;

  // Collections
  CollectionReference<Map<String, dynamic>> get _appsCollection =>
      _firestore.collection('external_apps');

  CollectionReference<Map<String, dynamic>> get _tokensCollection =>
      _firestore.collection('api_tokens');

  CollectionReference<Map<String, dynamic>> get _apiLogsCollection =>
      _firestore.collection('api_logs');

  // ============================================================
  // EXTERNAL APP REGISTRATION
  // ============================================================

  /// Register a new external app
  Future<ExternalApp> registerExternalApp({
    required String name,
    required String description,
    required String developerEmail,
    required AppType type,
    required List<String> requestedScopes,
    String? webhookUrl,
    String? redirectUri,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('ðŸ“± [PlatformAPI] Registering external app: $name');

    try {
      // Validate scopes
      final validScopes =
          requestedScopes.where((s) => APIScopes.all.contains(s)).toList();

      if (validScopes.isEmpty) {
        throw ArgumentError('At least one valid scope is required');
      }

      // Generate credentials
      final appId = _generateAppId();
      final clientId = _generateClientId();
      final clientSecret = _generateClientSecret();
      final clientSecretHash = _hashSecret(clientSecret);

      final app = ExternalApp(
        appId: appId,
        name: name,
        description: description,
        developerEmail: developerEmail,
        type: type,
        status:
            type == AppType.internal ? AppStatus.approved : AppStatus.pending,
        scopes: validScopes,
        clientId: clientId,
        clientSecretHash: clientSecretHash,
        webhookUrl: webhookUrl,
        redirectUri: redirectUri,
        registeredAt: DateTime.now(),
        approvedAt: type == AppType.internal ? DateTime.now() : null,
        metadata: metadata ?? {},
      );

      // Store in Firestore
      await _appsCollection.doc(appId).set(app.toMap());

      // Store client secret separately (encrypted in production)
      await _firestore.collection('app_secrets').doc(appId).set({
        'clientSecret': clientSecret, // In production, encrypt this
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Emit event
      _appController.add(app);

      // Track analytics
      AnalyticsService.instance.logEvent(
        name: 'external_app_registered',
        parameters: {
          'app_type': type.name,
          'scopes_count': validScopes.length,
        },
      );

      debugPrint('âœ… [PlatformAPI] App registered: $appId');
      return app;
    } catch (e) {
      debugPrint('âŒ [PlatformAPI] Failed to register app: $e');
      rethrow;
    }
  }

  String _generateAppId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(999999).toString().padLeft(6, '0');
    return 'app_${timestamp}_$random';
  }

  String _generateClientId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return 'mm_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  String _generateClientSecret() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _hashSecret(String secret) {
    final bytes = utf8.encode(secret);
    return sha256.convert(bytes).toString();
  }

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  /// Authenticate an external client and issue an access token
  Future<AccessToken?> authenticateExternalClient({
    required String clientId,
    required String clientSecret,
    List<String>? requestedScopes,
  }) async {
    debugPrint('ðŸ” [PlatformAPI] Authenticating client: $clientId');

    try {
      // Find app by client ID
      final appsQuery = await _appsCollection
          .where('clientId', isEqualTo: clientId)
          .limit(1)
          .get();

      if (appsQuery.docs.isEmpty) {
        debugPrint('âŒ [PlatformAPI] Client not found');
        return null;
      }

      final appDoc = appsQuery.docs.first;
      final app = ExternalApp.fromMap(appDoc.data());

      // Check app status
      if (app.status != AppStatus.approved) {
        debugPrint('âŒ [PlatformAPI] App not approved: ${app.status}');
        return null;
      }

      // Verify client secret
      final secretHash = _hashSecret(clientSecret);
      if (secretHash != app.clientSecretHash) {
        debugPrint('âŒ [PlatformAPI] Invalid client secret');

        // Log failed attempt
        await _logAPIAccess(
          appId: app.appId,
          action: 'auth_failed',
          success: false,
          metadata: {'reason': 'invalid_secret'},
        );

        return null;
      }

      // Determine scopes for token
      final grantedScopes = requestedScopes != null
          ? requestedScopes.where((s) => app.scopes.contains(s)).toList()
          : app.scopes;

      if (grantedScopes.isEmpty) {
        debugPrint('âŒ [PlatformAPI] No valid scopes requested');
        return null;
      }

      // Generate access token
      final token = _generateAccessToken();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));

      final accessToken = AccessToken(
        token: token,
        appId: app.appId,
        scopes: grantedScopes,
        issuedAt: now,
        expiresAt: expiresAt,
      );

      // Store token
      await _tokensCollection.doc(token).set(accessToken.toMap());

      // Emit event
      _tokenController.add(accessToken);

      // Log successful auth
      await _logAPIAccess(
        appId: app.appId,
        action: 'auth_success',
        success: true,
        metadata: {'scopes': grantedScopes},
      );

      debugPrint('âœ… [PlatformAPI] Token issued for: ${app.appId}');
      return accessToken;
    } catch (e) {
      debugPrint('âŒ [PlatformAPI] Authentication failed: $e');
      return null;
    }
  }

  String _generateAccessToken() {
    final bytes = List<int>.generate(48, (_) => _random.nextInt(256));
    return 'mm_tok_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  /// Validate an access token
  Future<AccessToken?> validateToken(String token) async {
    try {
      final tokenDoc = await _tokensCollection.doc(token).get();
      if (!tokenDoc.exists) return null;

      final data = tokenDoc.data()!;
      final accessToken = AccessToken(
        token: data['token'] as String,
        appId: data['appId'] as String,
        scopes: List<String>.from(data['scopes']),
        issuedAt: DateTime.parse(data['issuedAt'] as String),
        expiresAt: DateTime.parse(data['expiresAt'] as String),
      );

      if (accessToken.isExpired) {
        await _tokensCollection.doc(token).delete();
        return null;
      }

      return accessToken;
    } catch (e) {
      debugPrint('âŒ [PlatformAPI] Token validation failed: $e');
      return null;
    }
  }

  // ============================================================
  // ROOM APIs
  // ============================================================

  /// Expose room APIs for external consumption
  List<APIEndpoint> exposeRoomAPIs() {
    debugPrint('ðŸšª [PlatformAPI] Exposing Room APIs');

    return [
      const APIEndpoint(
        path: '/api/v1/rooms',
        method: 'GET',
        requiredScopes: [APIScopes.roomsRead],
        description: 'List all public rooms',
      ),
      const APIEndpoint(
        path: '/api/v1/rooms/:roomId',
        method: 'GET',
        requiredScopes: [APIScopes.roomsRead],
        description: 'Get room details',
      ),
      const APIEndpoint(
        path: '/api/v1/rooms',
        method: 'POST',
        requiredScopes: [APIScopes.roomsWrite],
        description: 'Create a new room',
      ),
      const APIEndpoint(
        path: '/api/v1/rooms/:roomId/join',
        method: 'POST',
        requiredScopes: [APIScopes.roomsWrite],
        description: 'Join a room',
      ),
      const APIEndpoint(
        path: '/api/v1/rooms/:roomId/leave',
        method: 'POST',
        requiredScopes: [APIScopes.roomsWrite],
        description: 'Leave a room',
      ),
      const APIEndpoint(
        path: '/api/v1/rooms/:roomId/participants',
        method: 'GET',
        requiredScopes: [APIScopes.roomsRead],
        description: 'List room participants',
      ),
      const APIEndpoint(
        path: '/api/v1/rooms/:roomId/spotlight',
        method: 'POST',
        requiredScopes: [APIScopes.roomsWrite],
        description: 'Trigger spotlight on a user',
        maxRequestsPerMinute: 10,
      ),
    ];
  }

  // ============================================================
  // CREATOR APIs
  // ============================================================

  /// Expose creator APIs for external consumption
  List<APIEndpoint> exposeCreatorAPIs() {
    debugPrint('â­ [PlatformAPI] Exposing Creator APIs');

    return [
      const APIEndpoint(
        path: '/api/v1/creators',
        method: 'GET',
        requiredScopes: [APIScopes.creatorsRead],
        description: 'List all creators',
      ),
      const APIEndpoint(
        path: '/api/v1/creators/:creatorId',
        method: 'GET',
        requiredScopes: [APIScopes.creatorsRead],
        description: 'Get creator profile',
      ),
      const APIEndpoint(
        path: '/api/v1/creators/:creatorId/stats',
        method: 'GET',
        requiredScopes: [APIScopes.creatorsRead, APIScopes.analyticsRead],
        description: 'Get creator statistics',
      ),
      const APIEndpoint(
        path: '/api/v1/creators/:creatorId/rooms',
        method: 'GET',
        requiredScopes: [APIScopes.creatorsRead, APIScopes.roomsRead],
        description: 'List creator\'s rooms',
      ),
      const APIEndpoint(
        path: '/api/v1/creators/:creatorId/follow',
        method: 'POST',
        requiredScopes: [APIScopes.creatorsWrite],
        description: 'Follow a creator',
      ),
      const APIEndpoint(
        path: '/api/v1/creators/:creatorId/subscribe',
        method: 'POST',
        requiredScopes: [APIScopes.creatorsWrite, APIScopes.paymentsWrite],
        description: 'Subscribe to a creator',
      ),
    ];
  }

  // ============================================================
  // ANALYTICS APIs
  // ============================================================

  /// Expose analytics APIs for external consumption
  List<APIEndpoint> exposeAnalyticsAPIs() {
    debugPrint('ðŸ“Š [PlatformAPI] Exposing Analytics APIs');

    return [
      const APIEndpoint(
        path: '/api/v1/analytics/rooms/:roomId',
        method: 'GET',
        requiredScopes: [APIScopes.analyticsRead],
        description: 'Get room analytics',
        maxRequestsPerMinute: 30,
      ),
      const APIEndpoint(
        path: '/api/v1/analytics/creators/:creatorId',
        method: 'GET',
        requiredScopes: [APIScopes.analyticsRead, APIScopes.creatorsRead],
        description: 'Get creator analytics',
        maxRequestsPerMinute: 30,
      ),
      const APIEndpoint(
        path: '/api/v1/analytics/engagement',
        method: 'GET',
        requiredScopes: [APIScopes.analyticsRead],
        description: 'Get engagement metrics',
        maxRequestsPerMinute: 20,
      ),
      const APIEndpoint(
        path: '/api/v1/analytics/revenue',
        method: 'GET',
        requiredScopes: [APIScopes.analyticsRead, APIScopes.paymentsRead],
        description: 'Get revenue analytics',
        maxRequestsPerMinute: 10,
      ),
      const APIEndpoint(
        path: '/api/v1/analytics/trends',
        method: 'GET',
        requiredScopes: [APIScopes.analyticsRead],
        description: 'Get platform trends',
        maxRequestsPerMinute: 20,
      ),
    ];
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  Future<void> _logAPIAccess({
    required String appId,
    required String action,
    required bool success,
    Map<String, dynamic>? metadata,
  }) async {
    await _apiLogsCollection.add({
      'appId': appId,
      'action': action,
      'success': success,
      'metadata': metadata ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get all registered apps
  Future<List<ExternalApp>> getRegisteredApps({AppStatus? status}) async {
    Query<Map<String, dynamic>> query = _appsCollection;

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot =
        await query.orderBy('registeredAt', descending: true).get();

    return snapshot.docs.map((doc) => ExternalApp.fromMap(doc.data())).toList();
  }

  /// Approve an external app
  Future<bool> approveApp(String appId) async {
    try {
      await _appsCollection.doc(appId).update({
        'status': AppStatus.approved.name,
        'approvedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('âŒ [PlatformAPI] Failed to approve app: $e');
      return false;
    }
  }

  /// Revoke an external app
  Future<bool> revokeApp(String appId) async {
    try {
      await _appsCollection.doc(appId).update({
        'status': AppStatus.revoked.name,
      });

      // Revoke all tokens for this app
      final tokensQuery =
          await _tokensCollection.where('appId', isEqualTo: appId).get();

      for (final doc in tokensQuery.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      debugPrint('âŒ [PlatformAPI] Failed to revoke app: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _appController.close();
    _tokenController.close();
  }
}
