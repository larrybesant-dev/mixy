import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/device_prefs_service.dart';
import '../../../services/web_device_enum_stub.dart'
    if (dart.library.html) '../../../services/web_device_enum_web.dart'
    as device_enum;

/// Bottom sheet that shows a compact camera preview, lets the user pick which
/// camera and microphone to use, and confirms before going live.
///
/// The sheet is purely informational — the actual camera enable/disable is
/// handled by the parent via [onConfirm]/[onCancel].
class CamPreviewSheet extends StatefulWidget {
  const CamPreviewSheet({
    super.key,
    required this.previewWidget,
    required this.onConfirm,
    required this.onCancel,
    this.isVideoEnabled = false,
  });

  /// The local camera preview widget (AgoraVideoView / WebRTC RTCVideoRenderer view).
  final Widget previewWidget;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isVideoEnabled;

  static Future<bool?> show(
    BuildContext context, {
    required Widget previewWidget,
    required bool isVideoEnabled,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF241820),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => CamPreviewSheet(
        previewWidget: previewWidget,
        isVideoEnabled: isVideoEnabled,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  State<CamPreviewSheet> createState() => _CamPreviewSheetState();
}

class _CamPreviewSheetState extends State<CamPreviewSheet> {
  final _prefs = DevicePrefsService();

  List<device_enum.MediaDeviceInfo> _cameras = const [];
  List<device_enum.MediaDeviceInfo> _mics = const [];
  String? _selectedCameraId;
  String? _selectedMicId;
  bool _devicesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await device_enum.enumerateMediaDevices();
      final savedCam = await _prefs.getPreferredCameraId();
      final savedMic = await _prefs.getPreferredMicId();
      if (!mounted) return;
      final cameras = devices.where((d) => d.kind == 'videoinput').toList();
      final mics = devices.where((d) => d.kind == 'audioinput').toList();
      setState(() {
        _cameras = cameras;
        _mics = mics;
        _selectedCameraId =
            (savedCam != null && cameras.any((c) => c.deviceId == savedCam))
            ? savedCam
            : (cameras.isNotEmpty ? cameras.first.deviceId : null);
        _selectedMicId =
            (savedMic != null && mics.any((m) => m.deviceId == savedMic))
            ? savedMic
            : (mics.isNotEmpty ? mics.first.deviceId : null);
        _devicesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _devicesLoading = false);
    }
  }

  Future<void> _onCameraChanged(String? id) async {
    if (id == null) return;
    setState(() => _selectedCameraId = id);
    await _prefs.setPreferredCameraId(id);
  }

  Future<void> _onMicChanged(String? id) async {
    if (id == null) return;
    setState(() => _selectedMicId = id);
    await _prefs.setPreferredMicId(id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3E47),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Camera Preview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          // ── Compact preview (16:9, max 200 px tall) ─────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: const Color(0xFF0D0A0C),
                  child: widget.isVideoEnabled
                      ? widget.previewWidget
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_off,
                                color: Color(0xFFB09080),
                                size: 32,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Camera not started yet',
                                style: TextStyle(
                                  color: Color(0xFFB09080),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // ── Device selectors ─────────────────────────────────────────
          if (kIsWeb) ...[
            if (_devicesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD4A853),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Loading devices…',
                      style: TextStyle(color: Color(0xFFB09080), fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (_cameras.isNotEmpty || _mics.isNotEmpty) ...[
              if (_cameras.isNotEmpty)
                _DeviceRow(
                  icon: Icons.videocam_outlined,
                  label: 'Camera',
                  devices: _cameras,
                  selectedId: _selectedCameraId,
                  onChanged: _onCameraChanged,
                ),
              if (_cameras.isNotEmpty && _mics.isNotEmpty)
                const SizedBox(height: 8),
              if (_mics.isNotEmpty)
                _DeviceRow(
                  icon: Icons.mic_outlined,
                  label: 'Microphone',
                  devices: _mics,
                  selectedId: _selectedMicId,
                  onChanged: _onMicChanged,
                ),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 10),
          // ── Action buttons ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3A3E47)),
                    foregroundColor: const Color(0xFFB09080),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Go Live 📷',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Device row: icon + label + dropdown ────────────────────────────────────

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.icon,
    required this.label,
    required this.devices,
    required this.selectedId,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final List<device_enum.MediaDeviceInfo> devices;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD4A853)),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB09080),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF10131A),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3A3E47)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3A3E47)),
              ),
            ),
            dropdownColor: const Color(0xFF241820),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: devices
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: d.deviceId,
                    child: Text(
                      d.label.isNotEmpty ? d.label : d.deviceId,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
