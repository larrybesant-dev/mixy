import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/logger.dart';

@immutable
class VelvetNoirVisualConfig {
  final double glassBlurSigma;
  final double glassBackgroundAlpha;
  final double goldBorderAlpha;
  final double wineGlowAlpha;
  final bool enableGlowEffects;

  const VelvetNoirVisualConfig({
    required this.glassBlurSigma,
    required this.glassBackgroundAlpha,
    required this.goldBorderAlpha,
    required this.wineGlowAlpha,
    required this.enableGlowEffects,
  });

  const VelvetNoirVisualConfig.defaults()
      : glassBlurSigma = 16.0,
        glassBackgroundAlpha = 0.65,
        goldBorderAlpha = 0.18,
        wineGlowAlpha = 0.08,
        enableGlowEffects = true;

  factory VelvetNoirVisualConfig.fromJson(Map<String, dynamic> json) {
    return VelvetNoirVisualConfig(
      glassBlurSigma: (json['glassBlurSigma'] as num?)?.toDouble() ?? 16.0,
      glassBackgroundAlpha:
          (json['glassBackgroundAlpha'] as num?)?.toDouble() ?? 0.65,
      goldBorderAlpha: (json['goldBorderAlpha'] as num?)?.toDouble() ?? 0.18,
      wineGlowAlpha: (json['wineGlowAlpha'] as num?)?.toDouble() ?? 0.08,
      enableGlowEffects: json['enableGlowEffects'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'glassBlurSigma': glassBlurSigma,
      'glassBackgroundAlpha': glassBackgroundAlpha,
      'goldBorderAlpha': goldBorderAlpha,
      'wineGlowAlpha': wineGlowAlpha,
      'enableGlowEffects': enableGlowEffects,
    };
  }
}

/// Provider for the FirebaseRemoteConfig instance.
final remoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  return FirebaseRemoteConfig.instance;
});

/// StateNotifier that initializes and exposes Velvet Noir visual configs.
final velvetVisualConfigProvider =
    StateNotifierProvider<VelvetVisualConfigNotifier, VelvetNoirVisualConfig>(
        (ref) {
  final rc = ref.watch(remoteConfigProvider);
  return VelvetVisualConfigNotifier(rc);
});

class VelvetVisualConfigNotifier extends StateNotifier<VelvetNoirVisualConfig> {
  final FirebaseRemoteConfig _rc;

  VelvetVisualConfigNotifier(this._rc)
      : super(const VelvetNoirVisualConfig.defaults()) {
    _initialize();
  }

  static const String _configKey = 'velvet_noir_visual_config';

  Future<void> _initialize() async {
    try {
      // Set defaults first so the app is always functional
      await _rc.setDefaults({
        _configKey:
            jsonEncode(const VelvetNoirVisualConfig.defaults().toJson()),
      });

      // Configure fetch settings
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 4),
      ));

      // Fetch and activate the configurations
      final updated = await _rc.fetchAndActivate();
      if (updated) {
        Logger.info(
            '[RemoteConfig] Fetched and activated new visual configurations.');
      } else {
        Logger.info('[RemoteConfig] Active visual config is up to date.');
      }

      // Parse the active config
      _updateStateFromRemote();
    } catch (e, st) {
      Logger.error('[RemoteConfig] Error initializing Remote Config: $e',
          error: e, stackTrace: st);
      // Fall back to safe defaults (state is already defaults)
    }
  }

  void _updateStateFromRemote() {
    final rawJson = _rc.getString(_configKey);
    if (rawJson.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        state = VelvetNoirVisualConfig.fromJson(decoded);
        Logger.info('[RemoteConfig] Loaded Velvet Noir config: $rawJson');
      }
    } catch (e, st) {
      Logger.error('[RemoteConfig] Error parsing visual config JSON: $e',
          error: e, stackTrace: st);
    }
  }

  /// Force manual refresh for debugging or operations
  Future<void> forceRefresh() async {
    try {
      await _rc.fetch();
      await _rc.activate();
      _updateStateFromRemote();
    } catch (e) {
      Logger.error('[RemoteConfig] Manual refresh failed: $e');
    }
  }
}
