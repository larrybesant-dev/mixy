import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/environment.dart';
import '../../core/logger.dart';

const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev-local',
);

class OperationalDebugOverlay extends StatefulWidget {
  const OperationalDebugOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<OperationalDebugOverlay> createState() => _OperationalDebugOverlayState();
}

class _OperationalDebugOverlayState extends State<OperationalDebugOverlay> {
  static const int _tapThreshold = 6;
  int _tapCount = 0;
  DateTime? _firstTapAt;
  bool _visible = false;

  void _registerTap() {
    final now = DateTime.now();
    if (_firstTapAt == null || now.difference(_firstTapAt!) > const Duration(seconds: 3)) {
      _firstTapAt = now;
      _tapCount = 0;
    }

    _tapCount += 1;
    if (_tapCount >= _tapThreshold) {
      _tapCount = 0;
      _firstTapAt = null;
      setState(() => _visible = !_visible);
    }
  }

  String _maskedUserId(String? uid) {
    if (uid == null || uid.isEmpty) {
      return 'anonymous';
    }
    if (uid.length <= 10) {
      return uid;
    }
    return '${uid.substring(0, 6)}...${uid.substring(uid.length - 4)}';
  }

  String _environmentLabel() {
    return switch (currentEnv) {
      Environment.dev => 'development',
      Environment.prod => 'production',
    };
  }

  String? _safeCurrentUserId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _safeCurrentUserId();

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: SizedBox(
              width: 34,
              height: 34,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _registerTap,
                onLongPress: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
        ),
        if (_visible)
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xEE0B0B0B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ValueListenableBuilder<LoggerErrorSnapshot?>(
                      valueListenable: Logger.lastCapturedErrorNotifier,
                      builder: (context, snapshot, _) {
                        final lastErrorLabel = snapshot == null
                            ? 'none'
                            : '${snapshot.message} (${snapshot.errorType ?? 'error'})';

                        return DefaultTextStyle(
                          style: const TextStyle(color: Color(0xFFF7EDE2), fontSize: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Operational Debug',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Version: $_appVersion'),
                              Text('Environment: ${_environmentLabel()}${kReleaseMode ? ' (release)' : ''}'),
                              Text('User: ${_maskedUserId(userId)}'),
                              const SizedBox(height: 6),
                              const Text(
                                'Last Error',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                lastErrorLabel,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
