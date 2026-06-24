// lib/services/token_service.dart
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Holds the full Agora token response from the Cloud Function.
class AgoraTokenData {
  final String token;
  final int uid;
  final String appId;
  final String channelName;

  const AgoraTokenData({
    required this.token,
    required this.uid,
    required this.appId,
    required this.channelName,
  });
}

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  // Lazy-loaded to ensure Firebase is initialized
  FirebaseFunctions? _functionsInstance;
  FirebaseFunctions get _functions =>
      _functionsInstance ??
      FirebaseFunctions.instanceFor(region: 'us-central1');

  // Generate Agora token for video chat
  Future<String> generateAgoraToken({
    required String channelName,
    required String userId,
    required bool isBroadcaster,
  }) async {
    return _withRetry(() async {
        final HttpsCallable callable =
          _functions.httpsCallable('generateAgoraToken'); // Endpoint: https://us-central1-mix-and-mingle-v2.cloudfunctions.net/generateAgoraToken
      final result = await callable.call(<String, dynamic>{
        'roomId': channelName,
        'userId': userId,
      });
      return result.data['token'] as String;
    }).catchError((e) {
      throw Exception('Failed to generate Agora token: $e');
    });
  }

  /// Generate Agora token and return full token data (token + numeric uid).
  /// Use this instead of [generateAgoraToken] when you need the Agora uid
  /// to pass to [AgoraService.joinChannel] or register platform view factories.
  Future<AgoraTokenData> generateAgoraTokenData({
    required String channelName,
    required String userId,
  }) async {
    return _withRetry(() async {
        final HttpsCallable callable =
          _functions.httpsCallable('generateAgoraToken'); // Endpoint: https://us-central1-mix-and-mingle-v2.cloudfunctions.net/generateAgoraToken
      final result = await callable.call(<String, dynamic>{
        'roomId': channelName,
        'userId': userId,
      });
      final data = result.data as Map<dynamic, dynamic>;
      return AgoraTokenData(
        token: data['token'] as String,
        uid: (data['uid'] as num).toInt(),
        appId: (data['appId'] as String?) ?? '',
        channelName: (data['channelName'] as String?) ?? channelName,
      );
    }).catchError((e) {
      throw Exception('Failed to generate Agora token: $e');
    });
  }

  // Validate token (optional - for security)
  Future<bool> validateToken(String token) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('validateToken');

      final result = await callable.call(<String, dynamic>{
        'token': token,
      });

      return result.data['valid'] as bool;
    } catch (e) {
      return false;
    }
  }

  // Refresh token if needed
  Future<String> refreshToken({
    required String channelName,
    required String userId,
    required bool isBroadcaster,
  }) async {
    // For now, just generate a new token
    // In production, you might want to check if current token is still valid
    return generateAgoraToken(
      channelName: channelName,
      userId: userId,
      isBroadcaster: isBroadcaster,
    );
  }

  /// Retry helper: up to [maxAttempts] with exponential backoff.
  /// Only retries on transient errors (network/timeout). Auth errors rethrown immediately.
  Future<T> _withRetry<T>(Future<T> Function() fn,
      {int maxAttempts = 3}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        final isAuthError = e.toString().contains('permission-denied') ||
            e.toString().contains('unauthenticated') ||
            e.toString().contains('UNAUTHENTICATED');
        if (isAuthError || attempt >= maxAttempts) rethrow;
        final delay = Duration(seconds: 1 << (attempt - 1)); // 1s, 2s, 4s
        if (kDebugMode) {
          debugPrint(
              '[TokenService] Attempt $attempt failed — retrying in ${delay.inSeconds}s: $e');
        }
        await Future.delayed(delay);
      }
    }
  }
}
