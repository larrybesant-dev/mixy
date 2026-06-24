// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/infra/app_health_service.dart';
import '../../services/agora/agora_web_bridge_v5.dart';
import '../../services/agora/agora_service.dart';
import '../../core/design_system/design_constants.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

/// Debug dashboard for testing Firebase and Agora health
class HealthDashboard extends ConsumerStatefulWidget {
  final String? agoraAppId;

  const HealthDashboard({
    this.agoraAppId,
    super.key,
  });

  @override
  ConsumerState<HealthDashboard> createState() => _HealthDashboardState();
}

class _HealthDashboardState extends ConsumerState<HealthDashboard> {
  late AppHealthService _service;
  final AgoraService _agora = AgoraService();
  bool _isLoading = false;
  String _lastAction = '';
  String _lastError = '';

  // Agora state
  bool _bridgeReady = false;
  bool _agoraInitialized = false;
  bool _inChannel = false;
  bool _cameraActive = false;
  bool _micActive = false;

  // Device selection
  List<Map<String, dynamic>> _devices = [];
  String? _selectedCamera;
  String? _selectedMic;
  bool _devicesLoaded = false;

  // Video preview registration
  static bool _viewFactoryRegistered = false;
  static const String _videoViewType = 'agora-video-preview';

  @override
  void initState() {
    super.initState();
    _service = ref.read(appHealthServiceProvider);
    _registerVideoViewFactory();
    _checkBridgeStatus();
  }

  void _registerVideoViewFactory() {
    if (!_viewFactoryRegistered) {
      // Register Flutter's HtmlElementView factory
      ui_web.platformViewRegistry.registerViewFactory(
        _videoViewType,
        (int viewId) {
          final div = web.document.createElement('div') as web.HTMLDivElement;
          div.id = 'agora-video-container';
          div.style.width = '100%';
          div.style.height = '100%';
          div.style.backgroundColor = '#1a1a1a';
          return div;
        },
      );
      _viewFactoryRegistered = true;
    }
  }

  Future<void> _loadDevices() async {
    if (_devicesLoaded) return;

    try {
      final devices = await _agora.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _devicesLoaded = true;

          // Auto-select first camera and mic
          final cameras =
              _devices.where((d) => d['kind'] == 'videoinput').toList();
          final mics =
              _devices.where((d) => d['kind'] == 'audioinput').toList();

          if (cameras.isNotEmpty) _selectedCamera = cameras.first['deviceId'];
          if (mics.isNotEmpty) _selectedMic = mics.first['deviceId'];
        });
      }
    } catch (e) {
      debugPrint('Failed to load devices: $e');
    }
  }

  void _checkBridgeStatus() {
    setState(() {
      _bridgeReady = AgoraWebBridge.isBridgeReady;
      final state = AgoraWebBridge.getState();
      _agoraInitialized = state['initialized'] ?? false;
      _inChannel = state['inChannel'] ?? false;
      _cameraActive = state['hasVideo'] ?? false;
      _micActive = state['hasAudio'] ?? false;
    });
  }

  void _showVideoContainer(bool show) {
    final container = web.document.getElementById('video-container');
    if (container != null) {
      (container as web.HTMLElement).style.display = show ? 'block' : 'none';
    }
  }

  Future<void> _runWithLoading(
      String action, Future<bool> Function() task) async {
    setState(() {
      _isLoading = true;
      _lastAction = action;
      _lastError = '';
    });

    try {
      final success = await task();
      if (!success) {
        _lastError = '$action failed';
      }
      _checkBridgeStatus();
    } catch (e) {
      _lastError = '$action error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        title: const Text('App Health Dashboard'),
        backgroundColor: DesignColors.surfaceDefault,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkBridgeStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agora Bridge Status (Real-time from JS)
            _buildSectionHeader('Agora Bridge Status'),
            const SizedBox(height: 8),
            _buildStatusCard([
              _buildStatusRow('JS Bridge Ready', _bridgeReady),
              _buildStatusRow('SDK Initialized', _agoraInitialized),
              _buildStatusRow('In Channel', _inChannel),
              _buildStatusRow('Camera Active', _cameraActive),
              _buildStatusRow('Mic Active', _micActive),
            ]),

            const SizedBox(height: 16),

            // Error display
            if (_lastError.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, color: Colors.red, size: 16),
                      onPressed: () => setState(() => _lastError = ''),
                    ),
                  ],
                ),
              ),

            // Loading indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DesignColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DesignColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Running: $_lastAction...',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

            // Agora Direct Tests
            _buildSectionHeader('Agora Direct Tests'),
            const SizedBox(height: 8),
            if (widget.agoraAppId == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add ?agoraAppId=YOUR_APP_ID to URL',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Video Preview
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: const HtmlElementView(viewType: _videoViewType),
                ),
              ),

              // Device Selection
              if (_devicesLoaded) ...[
                _buildDeviceDropdown(
                  label: 'Camera',
                  icon: Icons.videocam,
                  deviceKind: 'videoinput',
                  selectedValue: _selectedCamera,
                  onChanged: (val) async {
                    setState(() => _selectedCamera = val);
                    if (val != null && _cameraActive) {
                      await _agora.switchCamera(val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildDeviceDropdown(
                  label: 'Microphone',
                  icon: Icons.mic,
                  deviceKind: 'audioinput',
                  selectedValue: _selectedMic,
                  onChanged: (val) async {
                    setState(() => _selectedMic = val);
                    if (val != null && _micActive) {
                      await _agora.switchMic(val);
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              _buildTestButton(
                '1. Init Agora',
                Icons.hub,
                Colors.purple,
                () => _runWithLoading(
                  'Init Agora',
                  () async {
                    final ok = await _agora.init(widget.agoraAppId!);
                    if (ok) await _loadDevices();
                    return ok;
                  },
                ),
              ),
              _buildTestButton(
                '2. Start Camera',
                Icons.videocam,
                Colors.blue,
                () => _runWithLoading('Start Camera', () async {
                  _showVideoContainer(true);
                  final ok = await _agora.startCamera(
                      'agora-video-container', _selectedCamera);
                  _cameraActive = ok;
                  return ok;
                }),
              ),
              _buildTestButton(
                '3. Start Microphone',
                Icons.mic,
                Colors.teal,
                () => _runWithLoading(
                  'Start Mic',
                  () async {
                    final ok = await _agora.startMic(_selectedMic);
                    _micActive = ok;
                    return ok;
                  },
                ),
              ),
              _buildTestButton(
                'Leave / Cleanup',
                Icons.exit_to_app,
                Colors.red,
                () => _runWithLoading('Leave', () async {
                  _showVideoContainer(false);
                  await _agora.leaveChannel();
                  _cameraActive = false;
                  _micActive = false;
                  return true;
                }),
              ),
            ],

            const SizedBox(height: 24),

            // Firebase Tests
            _buildSectionHeader('Firebase Tests'),
            const SizedBox(height: 8),
            _buildTestButton(
              'Test Firebase Core',
              Icons.cloud,
              Colors.orange,
              () => _runWithLoading('Firebase Core', () async {
                await _service.testFirebaseCore();
                return _service.firebaseCore;
              }),
            ),
            _buildTestButton(
              'Test Firebase Auth',
              Icons.person,
              Colors.green,
              () => _runWithLoading('Firebase Auth', () async {
                await _service.testFirebaseAuth();
                return _service.firebaseAuth;
              }),
            ),
            _buildTestButton(
              'Test Firestore',
              Icons.storage,
              Colors.cyan,
              () => _runWithLoading('Firestore', () async {
                await _service.testFirestore();
                return _service.firestore;
              }),
            ),

            const SizedBox(height: 24),

            // Status Summary
            _buildSectionHeader('Status Summary'),
            const SizedBox(height: 8),
            _buildStatusSummary(),

            const SizedBox(height: 24),

            // Debug Info
            _buildSectionHeader('Debug Console'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open Browser DevTools (F12) and run:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _buildCodeLine('agoraDebug()'),
                  _buildCodeLine('agoraWebGetState()'),
                  _buildCodeLine('console.table(agoraWebBridge.getState())'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeLine(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatusCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status
                  ? DesignColors.success.withValues(alpha: 0.2)
                  : DesignColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status ? Icons.check_circle : Icons.error,
                  color: status ? DesignColors.success : DesignColors.error,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  status ? 'OK' : 'FAIL',
                  style: TextStyle(
                    color: status ? DesignColors.success : DesignColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.2),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: color.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSummary() {
    final status = _service.getAllStatus();
    final passed = status.values.where((v) => v).length;
    final total = status.length;
    final percentage = total > 0 ? (passed / total * 100).round() : 0;

    Color progressColor;
    if (percentage >= 80) {
      progressColor = DesignColors.success;
    } else if (percentage >= 50) {
      progressColor = Colors.orange;
    } else {
      progressColor = DesignColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$passed/$total',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'tests passed',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage% Health Score',
            style: TextStyle(
              color: progressColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDropdown({
    required String label,
    required IconData icon,
    required String deviceKind,
    required String? selectedValue,
    required Function(String?) onChanged,
  }) {
    final deviceList = _devices.where((d) => d['kind'] == deviceKind).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              dropdownColor: DesignColors.surfaceDefault,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: deviceList.map((d) {
                final deviceId = d['deviceId'] as String;
                final deviceLabel = d['label'] as String;
                return DropdownMenuItem(
                  value: deviceId,
                  child: Text(
                    deviceLabel.isEmpty
                        ? 'Device ${deviceList.indexOf(d) + 1}'
                        : deviceLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) => onChanged(val),
            ),
          ),
        ],
      ),
    );
  }
}
