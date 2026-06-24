/// OAuth Provider
///
/// Manages OAuth 2.0 authentication flows for the Mix & Mingle platform,
/// including authorization code flow, token management, and provider integration.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';

/// OAuth provider types
enum OAuthProviderType {
  google,
  apple,
  facebook,
  twitter,
  discord,
  twitch,
  github,
  microsoft,
  custom,
}

/// OAuth grant types
enum OAuthGrantType {
  authorizationCode,
  clientCredentials,
  refreshToken,
  implicit,
}

/// OAuth provider configuration
class OAuthProviderConfig {
  final String id;
  final OAuthProviderType type;
  final String clientId;
  final String clientSecret;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String? userInfoEndpoint;
  final String? revocationEndpoint;
  final List<String> scopes;
  final String redirectUri;
  final bool pkceEnabled;
  final Map<String, String> additionalParams;

  const OAuthProviderConfig({
    required this.id,
    required this.type,
    required this.clientId,
    required this.clientSecret,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.userInfoEndpoint,
    this.revocationEndpoint,
    required this.scopes,
    required this.redirectUri,
    this.pkceEnabled = true,
    this.additionalParams = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'clientId': clientId,
        'clientSecretHash': _hashSecret(clientSecret),
        'authorizationEndpoint': authorizationEndpoint,
        'tokenEndpoint': tokenEndpoint,
        'userInfoEndpoint': userInfoEndpoint,
        'revocationEndpoint': revocationEndpoint,
        'scopes': scopes,
        'redirectUri': redirectUri,
        'pkceEnabled': pkceEnabled,
        'additionalParams': additionalParams,
      };

  static String _hashSecret(String secret) {
    return sha256.convert(utf8.encode(secret)).toString();
  }
}

/// Authorization request
class AuthorizationRequest {
  final String state;
  final String? codeVerifier;
  final String? codeChallenge;
  final String providerId;
  final List<String> scopes;
  final String redirectUri;
  final DateTime createdAt;
  final DateTime expiresAt;

  const AuthorizationRequest({
    required this.state,
    this.codeVerifier,
    this.codeChallenge,
    required this.providerId,
    required this.scopes,
    required this.redirectUri,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'state': state,
        'codeVerifier': codeVerifier,
        'codeChallenge': codeChallenge,
        'providerId': providerId,
        'scopes': scopes,
        'redirectUri': redirectUri,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// OAuth tokens
class OAuthTokens {
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final String tokenType;
  final List<String> scopes;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const OAuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.tokenType = 'Bearer',
    required this.scopes,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'idToken': idToken,
        'tokenType': tokenType,
        'scopes': scopes,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory OAuthTokens.fromMap(Map<String, dynamic> map) => OAuthTokens(
        accessToken: map['accessToken'] as String,
        refreshToken: map['refreshToken'] as String?,
        idToken: map['idToken'] as String?,
        tokenType: map['tokenType'] as String? ?? 'Bearer',
        scopes: List<String>.from(map['scopes'] ?? []),
        issuedAt: DateTime.parse(map['issuedAt'] as String),
        expiresAt: DateTime.parse(map['expiresAt'] as String),
      );
}

/// OAuth user info
class OAuthUserInfo {
  final String id;
  final String? email;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? picture;
  final bool emailVerified;
  final Map<String, dynamic> raw;

  const OAuthUserInfo({
    required this.id,
    this.email,
    this.name,
    this.firstName,
    this.lastName,
    this.picture,
    this.emailVerified = false,
    this.raw = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'picture': picture,
        'emailVerified': emailVerified,
        'raw': raw,
      };
}

/// OAuth connection result
class OAuthConnectionResult {
  final bool success;
  final OAuthTokens? tokens;
  final OAuthUserInfo? userInfo;
  final String? error;
  final String? errorDescription;

  const OAuthConnectionResult({
    required this.success,
    this.tokens,
    this.userInfo,
    this.error,
    this.errorDescription,
  });

  factory OAuthConnectionResult.success(
    OAuthTokens tokens, {
    OAuthUserInfo? userInfo,
  }) =>
      OAuthConnectionResult(
        success: true,
        tokens: tokens,
        userInfo: userInfo,
      );

  factory OAuthConnectionResult.failure(
    String error, {
    String? description,
  }) =>
      OAuthConnectionResult(
        success: false,
        error: error,
        errorDescription: description,
      );
}

/// OAuth Provider Service
class OAuthProvider {
  static OAuthProvider? _instance;
  static OAuthProvider get instance => _instance ??= OAuthProvider._();

  OAuthProvider._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _random = Random.secure();

  // Active authorization requests (state -> request)
  final Map<String, AuthorizationRequest> _pendingRequests = {};

  // Stream controllers
  final _connectionController =
      StreamController<OAuthConnectionResult>.broadcast();

  Stream<OAuthConnectionResult> get connectionStream =>
      _connectionController.stream;

  // Collections
  CollectionReference<Map<String, dynamic>> get _providersCollection =>
      _firestore.collection('oauth_providers');

  CollectionReference<Map<String, dynamic>> get _connectionsCollection =>
      _firestore.collection('oauth_connections');

  // ============================================================
  // PROVIDER CONFIGURATION
  // ============================================================

  /// Configure an OAuth provider
  Future<OAuthProviderConfig> configureProvider({
    required OAuthProviderType type,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    List<String>? scopes,
    String? authorizationEndpoint,
    String? tokenEndpoint,
    String? userInfoEndpoint,
    bool pkceEnabled = true,
  }) async {
    debugPrint('ðŸ” [OAuthProvider] Configuring provider: ${type.name}');

    try {
      final endpoints = _getDefaultEndpoints(type);

      final config = OAuthProviderConfig(
        id: 'oauth_${type.name}_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        clientId: clientId,
        clientSecret: clientSecret,
        authorizationEndpoint:
            authorizationEndpoint ?? endpoints['authorization']!,
        tokenEndpoint: tokenEndpoint ?? endpoints['token']!,
        userInfoEndpoint: userInfoEndpoint ?? endpoints['userInfo'],
        scopes: scopes ?? _getDefaultScopes(type),
        redirectUri: redirectUri,
        pkceEnabled: pkceEnabled,
      );

      await _providersCollection.doc(config.id).set(config.toMap());

      AnalyticsService.instance.logEvent(
        name: 'oauth_provider_configured',
        parameters: {'type': type.name},
      );

      debugPrint('âœ… [OAuthProvider] Provider configured: ${type.name}');
      return config;
    } catch (e) {
      debugPrint('âŒ [OAuthProvider] Failed to configure provider: $e');
      rethrow;
    }
  }

  Map<String, String> _getDefaultEndpoints(OAuthProviderType type) =>
      switch (type) {
        OAuthProviderType.google => {
            'authorization': 'https://accounts.google.com/o/oauth2/v2/auth',
            'token': 'https://oauth2.googleapis.com/token',
            'userInfo': 'https://www.googleapis.com/oauth2/v3/userinfo',
          },
        OAuthProviderType.apple => {
            'authorization': 'https://appleid.apple.com/auth/authorize',
            'token': 'https://appleid.apple.com/auth/token',
            'userInfo': '',
          },
        OAuthProviderType.facebook => {
            'authorization': 'https://www.facebook.com/v18.0/dialog/oauth',
            'token': 'https://graph.facebook.com/v18.0/oauth/access_token',
            'userInfo': 'https://graph.facebook.com/me',
          },
        OAuthProviderType.twitter => {
            'authorization': 'https://twitter.com/i/oauth2/authorize',
            'token': 'https://api.twitter.com/2/oauth2/token',
            'userInfo': 'https://api.twitter.com/2/users/me',
          },
        OAuthProviderType.discord => {
            'authorization': 'https://discord.com/api/oauth2/authorize',
            'token': 'https://discord.com/api/oauth2/token',
            'userInfo': 'https://discord.com/api/users/@me',
          },
        OAuthProviderType.twitch => {
            'authorization': 'https://id.twitch.tv/oauth2/authorize',
            'token': 'https://id.twitch.tv/oauth2/token',
            'userInfo': 'https://api.twitch.tv/helix/users',
          },
        OAuthProviderType.github => {
            'authorization': 'https://github.com/login/oauth/authorize',
            'token': 'https://github.com/login/oauth/access_token',
            'userInfo': 'https://api.github.com/user',
          },
        OAuthProviderType.microsoft => {
            'authorization':
                'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
            'token':
                'https://login.microsoftonline.com/common/oauth2/v2.0/token',
            'userInfo': 'https://graph.microsoft.com/v1.0/me',
          },
        OAuthProviderType.custom => {
            'authorization': '',
            'token': '',
            'userInfo': '',
          },
      };

  List<String> _getDefaultScopes(OAuthProviderType type) => switch (type) {
        OAuthProviderType.google => ['openid', 'email', 'profile'],
        OAuthProviderType.apple => ['name', 'email'],
        OAuthProviderType.facebook => ['email', 'public_profile'],
        OAuthProviderType.twitter => [
            'tweet.read',
            'users.read',
            'offline.access'
          ],
        OAuthProviderType.discord => ['identify', 'email'],
        OAuthProviderType.twitch => ['user:read:email'],
        OAuthProviderType.github => ['read:user', 'user:email'],
        OAuthProviderType.microsoft => [
            'openid',
            'email',
            'profile',
            'offline_access'
          ],
        OAuthProviderType.custom => [],
      };

  // ============================================================
  // AUTHORIZATION FLOW
  // ============================================================

  /// Start authorization code flow
  Future<String> startAuthorization({
    required String providerId,
    List<String>? additionalScopes,
    Map<String, String>? additionalParams,
  }) async {
    debugPrint('ðŸš€ [OAuthProvider] Starting authorization for: $providerId');

    try {
      // Get provider config
      final providerDoc = await _providersCollection.doc(providerId).get();
      if (!providerDoc.exists) {
        throw Exception('Provider not found: $providerId');
      }

      final providerData = providerDoc.data()!;
      final scopes = <String>{
        ...(providerData['scopes'] as List).cast<String>(),
        ...?additionalScopes,
      }.toList();

      // Generate state and PKCE values
      final state = _generateState();
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      // Create authorization request
      final request = AuthorizationRequest(
        state: state,
        codeVerifier: codeVerifier,
        codeChallenge: codeChallenge,
        providerId: providerId,
        scopes: scopes,
        redirectUri: providerData['redirectUri'] as String,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      // Store pending request
      _pendingRequests[state] = request;

      // Build authorization URL
      final params = {
        'client_id': providerData['clientId'] as String,
        'redirect_uri': request.redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'state': state,
        if (providerData['pkceEnabled'] == true) ...{
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
        ...?additionalParams,
        ...(providerData['additionalParams'] as Map<String, dynamic>?)
                ?.cast<String, String>() ??
            {},
      };

      final authUrl = Uri.parse(providerData['authorizationEndpoint'] as String)
          .replace(queryParameters: params);

      debugPrint('âœ… [OAuthProvider] Authorization URL generated');
      return authUrl.toString();
    } catch (e) {
      debugPrint('âŒ [OAuthProvider] Failed to start authorization: $e');
      rethrow;
    }
  }

  String _generateState() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeVerifier() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Handle authorization callback
  Future<OAuthConnectionResult> handleCallback({
    required String code,
    required String state,
    String? error,
    String? errorDescription,
  }) async {
    debugPrint('ðŸ“¥ [OAuthProvider] Handling callback');

    // Check for errors
    if (error != null) {
      final result = OAuthConnectionResult.failure(
        error,
        description: errorDescription,
      );
      _connectionController.add(result);
      return result;
    }

    try {
      // Validate state
      final request = _pendingRequests[state];
      if (request == null || request.isExpired) {
        throw Exception('Invalid or expired state');
      }

      // Remove pending request
      _pendingRequests.remove(state);

      // Exchange code for tokens
      final tokens = await _exchangeCodeForTokens(
        code: code,
        providerId: request.providerId,
        codeVerifier: request.codeVerifier,
        redirectUri: request.redirectUri,
      );

      // Fetch user info
      OAuthUserInfo? userInfo;
      final providerDoc =
          await _providersCollection.doc(request.providerId).get();
      if (providerDoc.exists) {
        final userInfoEndpoint =
            providerDoc.data()?['userInfoEndpoint'] as String?;
        if (userInfoEndpoint != null && userInfoEndpoint.isNotEmpty) {
          userInfo = await _fetchUserInfo(
            userInfoEndpoint,
            tokens.accessToken,
          );
        }
      }

      // Store connection
      await _storeConnection(
        providerId: request.providerId,
        tokens: tokens,
        userInfo: userInfo,
      );

      final result = OAuthConnectionResult.success(tokens, userInfo: userInfo);
      _connectionController.add(result);

      AnalyticsService.instance.logEvent(
        name: 'oauth_connection_success',
        parameters: {'provider_id': request.providerId},
      );

      debugPrint('âœ… [OAuthProvider] Authorization successful');
      return result;
    } catch (e) {
      debugPrint('âŒ [OAuthProvider] Callback handling failed: $e');
      final result = OAuthConnectionResult.failure(e.toString());
      _connectionController.add(result);
      return result;
    }
  }

  Future<OAuthTokens> _exchangeCodeForTokens({
    required String code,
    required String providerId,
    String? codeVerifier,
    required String redirectUri,
  }) async {
    // In production, make actual HTTP request to token endpoint
    // Simulated response
    await Future.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    return OAuthTokens(
      accessToken: _generateAccessToken(),
      refreshToken: _generateRefreshToken(),
      scopes: ['email', 'profile'],
      issuedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
  }

  String _generateAccessToken() {
    final bytes = List<int>.generate(48, (_) => _random.nextInt(256));
    return 'ya29.${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  String _generateRefreshToken() {
    final bytes = List<int>.generate(64, (_) => _random.nextInt(256));
    return '1//${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  Future<OAuthUserInfo?> _fetchUserInfo(
    String endpoint,
    String accessToken,
  ) async {
    // In production, make actual HTTP request
    // Simulated response
    await Future.delayed(const Duration(milliseconds: 100));

    return OAuthUserInfo(
      id: 'user_${_random.nextInt(999999)}',
      email: 'user@example.com',
      name: 'Test User',
      emailVerified: true,
    );
  }

  Future<void> _storeConnection({
    required String providerId,
    required OAuthTokens tokens,
    OAuthUserInfo? userInfo,
  }) async {
    final connectionId = 'conn_${DateTime.now().millisecondsSinceEpoch}';

    await _connectionsCollection.doc(connectionId).set({
      'connectionId': connectionId,
      'providerId': providerId,
      'tokens': tokens.toMap(),
      'userInfo': userInfo?.toMap(),
      'connectedAt': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================

  /// Refresh access token
  Future<OAuthTokens?> refreshAccessToken({
    required String providerId,
    required String refreshToken,
  }) async {
    debugPrint('ðŸ”„ [OAuthProvider] Refreshing token');

    try {
      // In production, make actual HTTP request
      await Future.delayed(const Duration(milliseconds: 200));

      final now = DateTime.now();
      return OAuthTokens(
        accessToken: _generateAccessToken(),
        refreshToken: _generateRefreshToken(),
        scopes: ['email', 'profile'],
        issuedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
    } catch (e) {
      debugPrint('âŒ [OAuthProvider] Token refresh failed: $e');
      return null;
    }
  }

  /// Revoke tokens
  Future<bool> revokeTokens({
    required String providerId,
    required String accessToken,
  }) async {
    debugPrint('ðŸ—‘ï¸ [OAuthProvider] Revoking tokens');

    try {
      // In production, call revocation endpoint
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      debugPrint('âŒ [OAuthProvider] Token revocation failed: $e');
      return false;
    }
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Get configured providers
  Future<List<OAuthProviderType>> getConfiguredProviders() async {
    final snapshot = await _providersCollection.get();

    return snapshot.docs.map((doc) {
      final type = doc.data()['type'] as String;
      return OAuthProviderType.values.firstWhere(
        (t) => t.name == type,
        orElse: () => OAuthProviderType.custom,
      );
    }).toList();
  }

  /// Get user's OAuth connections
  Future<List<Map<String, dynamic>>> getUserConnections(String userId) async {
    final snapshot =
        await _connectionsCollection.where('userId', isEqualTo: userId).get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Disconnect OAuth provider
  Future<bool> disconnectProvider(String connectionId) async {
    try {
      await _connectionsCollection.doc(connectionId).delete();
      return true;
    } catch (e) {
      debugPrint('âŒ [OAuthProvider] Disconnect failed: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionController.close();
  }
}
