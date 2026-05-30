import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/logger.dart';
import 'package:mixvy/features/room/contracts/room_visibility_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _discoverableMinutesKey = 'rooms_visibility_discoverable_minutes';
const String _warmMinutesKey = 'rooms_visibility_warm_minutes';
const String _coldEndedMinutesKey = 'rooms_visibility_cold_ended_minutes';

const int _defaultDiscoverableMinutes = 15;
const int _defaultWarmMinutes = 360;
const int _defaultColdEndedMinutes = 720;

const String _cacheDiscoverableMinutesKey =
    'rooms_visibility_cache_discoverable_minutes';
const String _cacheWarmMinutesKey = 'rooms_visibility_cache_warm_minutes';
const String _cacheColdEndedMinutesKey =
    'rooms_visibility_cache_cold_ended_minutes';
const String _cacheUpdatedAtMsKey = 'rooms_visibility_cache_updated_at_ms';

enum RoomVisibilityPolicySource { defaults, cached, remote }

class RoomVisibilityPolicyState {
  const RoomVisibilityPolicyState({
    required this.windows,
    required this.source,
    required this.lastUpdatedAt,
    required this.isConfigValid,
    this.configIssue,
  });

  final RoomVisibilityWindows windows;
  final RoomVisibilityPolicySource source;
  final DateTime? lastUpdatedAt;
  final bool isConfigValid;
  final String? configIssue;
}

class _SanitizedVisibilityWindows {
  const _SanitizedVisibilityWindows({
    required this.windows,
    required this.isValid,
    this.issue,
  });

  final RoomVisibilityWindows windows;
  final bool isValid;
  final String? issue;
}

int _clampMinutes(int value, {required int min, required int max}) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

RoomVisibilityWindows _windowsFromRemoteConfig(FirebaseRemoteConfig config) {
  final discoverableMinutes = _clampMinutes(
    config.getInt(_discoverableMinutesKey),
    min: 1,
    max: 120,
  );
  final warmMinutes = _clampMinutes(
    config.getInt(_warmMinutesKey),
    min: 5,
    max: 1440,
  );
  final coldEndedMinutes = _clampMinutes(
    config.getInt(_coldEndedMinutesKey),
    min: 10,
    max: 2880,
  );

  return RoomVisibilityWindows(
    discoverableWindow: Duration(minutes: discoverableMinutes),
    warmWindow: Duration(minutes: warmMinutes),
    coldEndedWindow: Duration(minutes: coldEndedMinutes),
  );
}

_SanitizedVisibilityWindows _sanitizeWindows(RoomVisibilityWindows input) {
  final discoverableMinutes = _clampMinutes(
    input.discoverableWindow.inMinutes,
    min: 1,
    max: 120,
  );
  final warmMinutes = _clampMinutes(
    input.warmWindow.inMinutes,
    min: 5,
    max: 1440,
  );
  final coldEndedMinutes = _clampMinutes(
    input.coldEndedWindow.inMinutes,
    min: 10,
    max: 2880,
  );

  final isOrdered =
      discoverableMinutes < warmMinutes && warmMinutes < coldEndedMinutes;
  if (isOrdered) {
    return _SanitizedVisibilityWindows(
      windows: RoomVisibilityWindows(
        discoverableWindow: Duration(minutes: discoverableMinutes),
        warmWindow: Duration(minutes: warmMinutes),
        coldEndedWindow: Duration(minutes: coldEndedMinutes),
      ),
      isValid: true,
    );
  }

  return _SanitizedVisibilityWindows(
    windows: RoomVisibilityWindows.defaults,
    isValid: false,
    issue: 'Invalid window ordering; expected discoverable < warm < coldEnded.',
  );
}

Future<RoomVisibilityPolicyState?> _readCachedPolicyState() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_cacheDiscoverableMinutesKey) ||
      !prefs.containsKey(_cacheWarmMinutesKey) ||
      !prefs.containsKey(_cacheColdEndedMinutesKey)) {
    return null;
  }

  final sanitized = _sanitizeWindows(
    RoomVisibilityWindows(
      discoverableWindow: Duration(
        minutes:
            prefs.getInt(_cacheDiscoverableMinutesKey) ??
            _defaultDiscoverableMinutes,
      ),
      warmWindow: Duration(
        minutes: prefs.getInt(_cacheWarmMinutesKey) ?? _defaultWarmMinutes,
      ),
      coldEndedWindow: Duration(
        minutes:
            prefs.getInt(_cacheColdEndedMinutesKey) ?? _defaultColdEndedMinutes,
      ),
    ),
  );

  final updatedAtMs = prefs.getInt(_cacheUpdatedAtMsKey);
  return RoomVisibilityPolicyState(
    windows: sanitized.windows,
    source: RoomVisibilityPolicySource.cached,
    lastUpdatedAt: updatedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    isConfigValid: sanitized.isValid,
    configIssue: sanitized.issue,
  );
}

Future<void> _writeCachedPolicyState(RoomVisibilityWindows windows) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    _cacheDiscoverableMinutesKey,
    windows.discoverableWindow.inMinutes,
  );
  await prefs.setInt(_cacheWarmMinutesKey, windows.warmWindow.inMinutes);
  await prefs.setInt(
    _cacheColdEndedMinutesKey,
    windows.coldEndedWindow.inMinutes,
  );
  await prefs.setInt(
    _cacheUpdatedAtMsKey,
    DateTime.now().millisecondsSinceEpoch,
  );
}

final firebaseRemoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  return FirebaseRemoteConfig.instance;
});

final roomVisibilityPolicyStateProvider =
    StateProvider<RoomVisibilityPolicyState>((ref) {
      return const RoomVisibilityPolicyState(
        windows: RoomVisibilityWindows.defaults,
        source: RoomVisibilityPolicySource.defaults,
        lastUpdatedAt: null,
        isConfigValid: true,
      );
    });

final roomVisibilityWindowsBootstrapProvider = FutureProvider<void>((
  ref,
) async {
  final cachedState = await _readCachedPolicyState();
  if (cachedState != null) {
    ref.read(roomVisibilityPolicyStateProvider.notifier).state = cachedState;
    Logger.info(
      'ROOM_VISIBILITY loaded_cached_windows discoverableMin=${cachedState.windows.discoverableWindow.inMinutes} warmMin=${cachedState.windows.warmWindow.inMinutes} coldEndedMin=${cachedState.windows.coldEndedWindow.inMinutes}',
    );
  }

  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);

  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 8),
      minimumFetchInterval: const Duration(minutes: 30),
    ),
  );

  await remoteConfig.setDefaults(<String, dynamic>{
    _discoverableMinutesKey: _defaultDiscoverableMinutes,
    _warmMinutesKey: _defaultWarmMinutes,
    _coldEndedMinutesKey: _defaultColdEndedMinutes,
  });

  try {
    await remoteConfig.fetchAndActivate();
  } catch (error, stackTrace) {
    Logger.warning(
      'ROOM_VISIBILITY remote_config_fetch_failed; using cached/default windows',
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }

  final sanitized = _sanitizeWindows(_windowsFromRemoteConfig(remoteConfig));
  final state = RoomVisibilityPolicyState(
    windows: sanitized.windows,
    source: RoomVisibilityPolicySource.remote,
    lastUpdatedAt: DateTime.now(),
    isConfigValid: sanitized.isValid,
    configIssue: sanitized.issue,
  );
  ref.read(roomVisibilityPolicyStateProvider.notifier).state = state;

  if (sanitized.isValid) {
    await _writeCachedPolicyState(sanitized.windows);
  } else {
    Logger.warning(
      'ROOM_VISIBILITY remote_windows_invalid issue=${sanitized.issue}; falling back to defaults',
    );
  }

  final windows = state.windows;
  Logger.info(
    'ROOM_VISIBILITY windows source=${state.source.name} discoverableMin=${windows.discoverableWindow.inMinutes} warmMin=${windows.warmWindow.inMinutes} coldEndedMin=${windows.coldEndedWindow.inMinutes} isValid=${state.isConfigValid}',
  );
});

final roomVisibilityWindowsProvider = Provider<RoomVisibilityWindows>((ref) {
  ref.watch(roomVisibilityWindowsBootstrapProvider);
  return ref.watch(roomVisibilityPolicyStateProvider).windows;
});




